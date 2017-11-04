%% SAP2000 Script - API integration

%Response Module

%This script performs the following operations:
%(1) Finds the x and y centroid of the structure
%(2) Applies Equivalent Lateral Forces at respective floor slab elevations
%(3) Calculates the response of the structure - current output is x and y
%displacements for loading in the x and y direction, respectively

%Note: This script was modified so that we can run all iterations of our
%ELFs without having to open and close SAP each time (saves time). When we
%move on to processing force information, we will need to take this into
%account as well

%% Input/Output for ResponseSapAPI
function[x_disp,y_disp,Joint_elev,JointNames,Gamma,Phi]=ResponseSapAPI(FrameObjNames,units,FilePathResponse,elev,Fj)
%Inputs:
%FrameObjNames - list of names of frame members from HazardSapAPI.m
%units - same as in HazardSapAPI.m
%FilePath - this will be the name of that from the HazardSapAPI.m model at
%the end
%Fj - matrix of ELFs for the num_int number of intensities specified in the
%Hazard Module

%Outputs: Ux,Uy --> vectors of displacements at the centroid of each floor for the x and y directions for
%each set of ELFs.

%% Full path to the program executable
ProgramPath = 'C:\Program Files (x86)\Computers and Structures\SAP2000 17\sap2000.exe';

%%
%pass data to Sap2000 as one-dimensional arrays
feature('COM_SafeArraySingleDim', 1);
%pass non-scalar arrays to Sap2000 API by reference
feature('COM_PassSafeArrayByRef', 1);

%% create OAPI helper object
helper = actxserver('Sap2000v17.helper');
helper = helper.invoke('cHelper');

%% create Sap2000 object
SapObject = helper.CreateObject(ProgramPath);
 
%% start Sap2000 application
SapObject.ApplicationStart;
SapObject.Hide; %This is here to prevent SAP from fully opening (runs our analysis faster)
%% create SapModel object
SapModel = SapObject.SapModel;

%Open existing file 
%This file will be the new one created at the end of HazardSapAPI.m (i.e. the one with the modal analysis) 
SapModel.File.OpenFile([FilePathResponse,'.sdb']); 

%% Edit Model 
% ---------- 
% Model lock =>(1)or unlock =>(0) 
SapModel.SetModelIsLocked(0);

ret = SapModel.SetPresentUnits(units);
%create the analysis model
ret = SapModel.Analyze.CreateAnalysisModel;

%% Centroid in X and Y direction:
%Since there are problems with the BaseReactWithCentroid we are going to
%manually pull the values of the centroid:
CentroidFile=xlsread('Centroid.xlsx');
Xc=CentroidFile(16);
Yc=CentroidFile(17);

%% Apply Equivalent Lateral Forces:

%Define a new load pattern for x and y directions of seismic loading:
%Inputs for Load Pattern: 
%(1) Name of new load pattern
%(2) Type of loading, in this case: LTYPE_QUAKE=5
%(3) Self weight multiplier==1
%(4) Add Load Case: if this item is true, a linear static load case
%corresponding to the new load pattern is added

ret = SapModel.LoadPatterns.Add('EQX', 5,1,true()); %Defines a seismic load case in the x direction
ret = SapModel.LoadPatterns.Add('EQY', 5,1,true());%Defines a seismic load case in the y direction


%Add points where the ELF will be applied:
%elev=elev*12;
MyName=zeros(length(elev)-1); %holder so that we can save the names of our new points for later

for i=1:length(elev)-1
    %add point object to model
    x=Xc;
    y=Yc;
    z=elev(i+1); %might need to change, depending on what Holly hands us 
    Name='';
    ret= SapModel.PointObj.AddCartesian(x, y, z, Name);
end

%Get joint coordinates:
%Count the number of point elements:
PointCount=SapModel.PointObj.Count;

%Get cartesian point element coordinates
%Initialize variables
xcoords=zeros(PointCount,1);
ycoords=zeros(PointCount,1);
zcoords=zeros(PointCount,1);
for i=1:PointCount
    PointNum=num2str(i);
    x=1;y=1;z=1; %dummy values of 1
    [ret,x,y,z] = SapModel.PointObj.GetCoordCartesian(PointNum, x, y, z,'Global');
    xcoords(i)=x;
    ycoords(i)=y;
    zcoords(i)=z;
end
%Matrix of Joint Numbers and Corresponding Coordinates in (x,y,z): Matrix
%coincides with presentation in Joint Coordinates Table in SAP2000
JointCoords=[[1:PointCount]' xcoords ycoords zcoords];
NewCoords=find(JointCoords(:,2)==Xc & JointCoords(:,3)==Yc);

%Matrix with (1) PointName (2)x (3)y (4)z for newly defined coordinates at
%centroid of structure:
CentJoints=JointCoords(NewCoords,:);

%% Assign diaphragm boundary condition to new points:
%In order to assign this boundary condition we need to know where the
%different heights of the floor slabs are (regardless if SAP model supplied
%does or does not have floors on it:

%define new constraint assignments
for d=1:length(elev)-1
   %Choose points which will be a part of the diaphragm constraint:
   PointsD=find(round(CentJoints(:,4))==elev(d+1));
   %Name of Diaphragm Constraint:
    DiaphName='Diaph%d';
    DNumber=d;
    Diaph=sprintf(DiaphName,DNumber); 
   for p=1:length(PointsD)
        ret = SapModel.PointObj.SetConstraint(num2str(CentJoints(PointsD(p))), Diaph,0); %look up constraint function 
   end
end

%% Apply Equivalent Lateral Forces:

%Initialize variable to save displacements:
x_disp=zeros(length(elev)-1,1);
y_disp=zeros(length(elev)-1,1);


%Inputs for SetLoadForce function:
%(1) PointName - the name of an existing point object or group depending on the
%value of the ItemType item
%(2) LoadPat - The name of the load pattern for the point load
%(3) PointLoadValue - This is an array of 6 point load values:
%Value(1)=F1, Value(2)=F2, Value(3)=F3
%Value(4)=M1, Value(5)=M2, Value(6)=M3
%(4) Replace - If this item is true, all previous point loads, if any,
%assinged to the specified point object(s) in the specified load pattern are
%deleted vefore making the new assignment
%(5) CSys - The name of the coordinate system for th considered point load.
%This is Local or the name of a defined coordinate system
%(6) ItemType - This is one of the following items in the eltemType
%enumeration:
%Object=0, Group=1, SelectedObjects=2

%Adding point loads for our ELFs:

%add point load(s)
for j=1:length(elev)-1
    %x-direction loading:
    PointLoadValue=zeros(6,1);
    PointName=num2str(CentJoints(j,1));
    LoadPat='EQX'; 
    PointLoadValue(1,1)=Fj(j,1);
    Replace=true;
    ret = SapModel.PointObj.SetLoadForce(PointName, LoadPat, PointLoadValue,Replace);

    %y-direction loading:
    PointLoadValue=zeros(6,1);
    PointName=num2str(CentJoints(j,1));
    LoadPat='EQY'; 
    PointLoadValue(2,1)=Fj(j,2);
    Replace=true;
    ret = SapModel.PointObj.SetLoadForce(PointName, LoadPat, PointLoadValue,Replace);
end

%% Run Analysis - ELFM

%run analysis
ret = SapModel.Analyze.RunAnalysis;


%% Centroid in X and Y Direction using BaseReactWithCentroid
% NumberResults=1;
% LoadCase=cellstr('');
% StepType=cellstr('');
% StepNum = reshape(0:1,2,1);
% Fx=reshape(0:1,2,1); Fy=reshape(0:1,2,1); Fz=reshape(0:1,2,1);
% Mx=reshape(0:1,2,1); My=reshape(0:1,2,1); Mz=reshape(0:1,2,1);
% gx=zeros(1,1,'double'); gy=zeros(1,1,'double'); gz=zeros(1,1,'double');
% XCentroidForFx=reshape(0:1,2,1); YCentroidForFx=reshape(0:1,2,1); ZCentroidForFx=reshape(0:1,2,1);
% XCentroidForFy=reshape(0:1,2,1); YCentroidForFy=reshape(0:1,2,1); ZCentroidForFy=reshape(0:1,2,1);
% XCentroidForFz=reshape(0:1,2,1); YCentroidForFz=reshape(0:1,2,1); ZCentroidForFz=reshape(0:1,2,1);

%NOTE: Problem with BaseReact function: does not give My and gives
%incorrect Mz - problem will be fixed when we move to version 18
%get base reactions
%[ret,NumberResults,LoadCase,StepType,StepNum,Fx,Fy,Fz,Mx,My,Mz,gx,gy,gz] = SapModel.Results.BaseReact(NumberResults, LoadCase, StepType, StepNum, Fx, Fy, Fz, Mx, My, Mz, gx, gy, gz)

%get base reactions with centroids
%Omitted output:
%(2)NumberResults (3)LoadCase (4)StepType (5) StepNum 
%(6)Fx (7)Fy (8)Fz (9)Mx (10)My (11)Mz (12)gx (13)gy (14)gz
%(15)XCentroidForFx (16)YCentroidForFx (17)ZCentroidForFx
%(18)XCentroidForFy (19)YCentroidForFy (20)ZCentroidForFy,
%[ret,NumberResults,LoadCase,StepType,StepNum,Fx,Fy,Fz,Mx,My,Mz,gx,gy,gz,XCentroidForFx ,YCentroidForFx,ZCentroidForFx,XCentroidForFy,YCentroidForFy,ZCentroidForFy,XCentroidForFz, YCentroidForFz, ZCentroidForFz] = SapModel.Results.BaseReactWithCentroid(NumberResults, LoadCase, StepType, StepNum, Fx, Fy, Fz, Mx, My, Mz, gx, gy, gz, XCentroidForFx, YCentroidForFx, ZCentroidForFx, XCentroidForFy, YCentroidForFy, ZCentroidForFy, XCentroidForFz, YCentroidForFz, ZCentroidForFz)

%% Results: x-direction loading 

%clear all case and combo output selections
ret = SapModel.Results.Setup.DeselectAllCasesAndCombosForOutput;

%set case and combo output selections - first we pull information for
%x-direction loading:
ret = SapModel.Results.Setup.SetCaseSelectedForOutput('EQX');

%-------------------------------------------------------------------------%
%For now, we are just pulling up displacements for the points corresponding
%to the centroid of each floor:
JointNames=CentJoints(:,1);
Ux=zeros(length(JointNames),1);

%These two lines are for when we decide to do this for all joints in the
%model:
%JointNames=JointCoords(:,1);
%x_disp=zeros(length(JointNames),1);

for k=1:length(JointNames)
    %Displacements:
    PointName=num2str(JointNames(k,:));
    NumberResults=0;
    Obj=cellstr('');
    Elm=cellstr('');
    LoadCase=cellstr('');
    StepType=cellstr('');
    StepNum=reshape(0:1,2,1);
    U1=reshape(0:1,2,1); U2=reshape(0:1,2,1); U3=reshape(0:1,2,1);
    R1=reshape(0:1,2,1); R2=reshape(0:1,2,1); R3=reshape(0:1,2,1);
    ObjectElm=0;

    %We are going to pull displacements in the x-direction
   [ret, NumberResults, Obj, Elm, LoadCase, StepType, StepNum, U1, U2, U3, R1, R2, R3] = SapModel.Results.JointDispl(PointName, ObjectElm, NumberResults, Obj, Elm, LoadCase, StepType, StepNum, U1, U2, U3, R1, R2, R3);
    Ux(k,:)=U1;
end
x_disp=Ux;

%% Get frame forces: x-direction

%Input for FrameForce function:
%(1) Name - the name of an existing line object, line element, or group of
%objects depending on the value of the ItemTypeElm item.
%(2) ItemTypeElm - ObjectElm=0, Element=1, GroupElm=2, SelectionElm=3
%(3) NumberResults - the total number of results returned by the program
%(4) Obj - this is an array that includes the line object name associated
%with each result, if any
%(5) ObjSta - this is an array that inlcudes the distance measured from the
%i-end of the line object to the result location
%(6) Elm - This is an array that includes the line element name associated
%with each result
%(7) ElmSta - this is an array that includes the distance measured from the
%i-end of the line element to the result location
%(8) LoadCase - This is an awway that includes the name of the analysis
%case or load combination associated with each result
%(9) StepType - This is an array that includes the step type, if any, for
%each result
%(10) Step Num - This is an array that includes the step number, if any,
%for each result
%(11-13) P, V2, V3 --> one-dimensional arrays
%(14-16) T, M2, M3 --> one-dimensional arrays
% 
% FrameNames=char(FrameObjNames); %it might be good to make this variable as an output in HazardSapAPI
% Px=zeros(length(FrameObjNames),3);
% V2x=zeros(length(FrameObjNames),3);
% V3x=zeros(length(FrameObjNames),3);
% Tx=zeros(length(FrameObjNames),3);
% M2x=zeros(length(FrameObjNames),3);
% M3x=zeros(length(FrameObjNames),3);
% 
% for g=1:length(FrameObjNames)
%     Object=0;
%     NumberResults=0;
%     Obj = cellstr(' ');
%     ObjSta=reshape(0:1,2,1);
%     Elm=cellstr('');
%     ElmSta=reshape(0:1,2,1);
%     LoadCase=cellstr('');
%     StepType=cellstr('');
%     StepNum = reshape(0:1,2,1);
%     P=reshape(0:1,2,1); V2=reshape(0:1,2,1); V3=reshape(0:1,2,1);
%     T=reshape(0:1,2,1); M2=reshape(0:1,2,1); M3=reshape(0:1,2,1);
% 
%     [ret, NumberResults, Obj, ObjSta, Elm, ElmSta, LoadCase, StepType, StepNum, P, V2, V3, T, M2, M3] = SapModel.Results.FrameForce(FrameNames(g,:), Object, NumberResults, Obj, ObjSta, Elm, ElmSta, LoadCase, StepType, StepNum, P, V2, V3, T, M2, M3)
% 
%     %Output: For each element force: Number of Results == 3 --> @0, @L/2, @L
%     Px(g,:)=P; %CURRENT PROBLEM: RESULTS ARE REPORTED IN MORE OR LESS LOCATIONS, DEPENDING ON MEMBER --> WE COULD PUT IN SOME QUERY THAT WILL ALLOW US TO DISTINGUISH BETWEEN MAX AND MIN VALUES?
%     V2x(g,:)=V2;
%     V3x(g,:)=V3;
%     Tx(g,:)=T;
%     M2x(g,:)=M2;
%     M3x(g,:)=M3;
% end

%% Results: y-direction loading

%clear all case and combo output selections
ret = SapModel.Results.Setup.DeselectAllCasesAndCombosForOutput;

%set case and combo output selections - first we pull information for
%x-direction loading:
ret = SapModel.Results.Setup.SetCaseSelectedForOutput('EQY');

%-------------------------------------------------------------------------%
%For now, we are just pulling up displacements for the points corresponding
%to the centroid of each floor:
JointNames=CentJoints(:,1);
Uy=zeros(length(JointNames),1);

%These two lines are for when we decide to do this for all joints in the
%model:
%JointNames=JointCoords(:,1);
%y_disp=zeros(length(JointNames),1);

for k=1:length(JointNames)
    %Displacements:
    PointName=num2str(JointNames(k,:));
    NumberResults=0;
    Obj=cellstr('');
    Elm=cellstr('');
    LoadCase=cellstr('');
    StepType=cellstr('');
    StepNum=reshape(0:1,2,1);
    U1=reshape(0:1,2,1); U2=reshape(0:1,2,1); U3=reshape(0:1,2,1);
    R1=reshape(0:1,2,1); R2=reshape(0:1,2,1); R3=reshape(0:1,2,1);
    ObjectElm=0;

    %We are going to pull displacements in the y-direction
   [ret, NumberResults, Obj, Elm, LoadCase, StepType, StepNum, U1, U2, U3, R1, R2, R3] = SapModel.Results.JointDispl(PointName, ObjectElm, NumberResults, Obj, Elm, LoadCase, StepType, StepNum, U1, U2, U3, R1, R2, R3);
    Uy(k,:)=U2;
end
y_disp=Uy;
%Here we are going to ask as output the z-coordinate of the centroid points
%that were used to query displacements in the x and the y, to make sure
%that we have the right order (bottom to top of structure):
Joint_elev=CentJoints(:,4); 

 
%% Get frame forces: y-direction
% 
% FrameNames=char(FrameObjNames); %it might be good to make this variable as an output in HazardSapAPI
% Py=zeros(length(FrameObjNames),3);
% V2y=zeros(length(FrameObjNames),3);
% V3y=zeros(length(FrameObjNames),3);
% Ty=zeros(length(FrameObjNames),3);
% M2y=zeros(length(FrameObjNames),3);
% M3y=zeros(length(FrameObjNames),3);
% 
% for g=1:length(FrameObjNames)
%     Object=0;
%     NumberResults=0;
%     Obj = cellstr(' ');
%     ObjSta=reshape(0:1,2,1);
%     Elm=cellstr('');
%     ElmSta=reshape(0:1,2,1);
%     LoadCase=cellstr('');
%     StepType=cellstr('');
%     StepNum = reshape(0:1,2,1);
%     P=reshape(0:1,2,1); V2=reshape(0:1,2,1); V3=reshape(0:1,2,1);
%     T=reshape(0:1,2,1); M2=reshape(0:1,2,1); M3=reshape(0:1,2,1);
% 
%     [ret, NumberResults, Obj, ObjSta, Elm, ElmSta, LoadCase, StepType, StepNum, P, V2, V3, T, M2, M3] = SapModel.Results.FrameForce(FrameNames(g,:), Object, NumberResults, Obj, ObjSta, Elm, ElmSta, LoadCase, StepType, StepNum, P, V2, V3, T, M2, M3)
% 
%     %Output: For each element force: Number of Results == 3 --> @0, @L/2, @L
%     Py(g,:)=P;
%     V2y(g,:)=V2;
%     V3y(g,:)=V3;
%     Ty(g,:)=T;
%     M2y(g,:)=M2;
%     M3y(g,:)=M3;
% end

%% Modal information:
%Make sure we are selecting the correct load case:
ret = SapModel.Results.Setup.DeselectAllCasesAndCombosForOutput;
ret = SapModel.Results.Setup.SetCaseSelectedForOutput('MODAL');

%-------------------------------------------------------------------------%
%Modal Participating Mass Ratios:
NumberResults=1;
LoadCase=cellstr('');
StepType=cellstr('');
StepNum = reshape(0:1,2,1);
Period = reshape(0:1,2,1);
Ux=reshape(0:1,2,1); Uy=reshape(0:1,2,1); Uz=reshape(0:1,2,1);
SumUx=reshape(0:1,2,1); SumUy=reshape(0:1,2,1); SumUz=reshape(0:1,2,1);
Rx=reshape(0:1,2,1); Ry=reshape(0:1,2,1); Rz=reshape(0:1,2,1);
SumRx=reshape(0:1,2,1); SumRy=reshape(0:1,2,1); SumRz=reshape(0:1,2,1);

%get modal participating mass ratios
%Omitted outputs (in order):
%NumberofModes,LoadCase,StepType,ModeNumber,Period
[ret,~,~,~,~,Period,Ux,Uy,Uz,SumUx,SumUy,SumUz,Rx,Ry,Rz,SumRx,SumRy,SumRz] = SapModel.Results.ModalParticipatingMassRatios(NumberResults, LoadCase, StepType, StepNum, Period, Ux, Uy, Uz, SumUx, SumUy, SumUz, Rx, Ry, Rz, SumRx, SumRy, SumRz);

%Figure out which fundamental mode corresponds to the x and y directions and grab the associated participation ratio:
Gamma=zeros(1,2);
for t=1:length(Ux)
    if Ux(t)==max(Ux)
        T1x=Period(t);
        Gamma(1)=Ux(t);
        ModeShape1=t; %Save what number of modeshape the x translation corresponds to
    else
        a=0;
    end
    if Uy(t)==max(Uy)
        T1y=Period(t);
        Gamma(2)=Uy(t);
        ModeShape2=t; %Save what number of modeshape the y translation corresponds to
    else
        b=0;
    end
end

%-------------------------------------------------------------------------%
%Modeshapes in the x and y direction at the location of the centroid
%joints:

Phi=zeros(length(elev)-1,2); %Rows are number of floor from 1 to n, columns are for x and y directions
JointNames=CentJoints(:,1);

for b=1:length(JointNames)
    Name=num2str(JointNames(b,:));
    GroupElm=1;
    NumberResults=1;
    Obj=cellstr('');
    Elm=cellstr('');
    LoadCase=cellstr('');
    StepType=cellstr('');
    StepNum = reshape(0:1,2,1);
    U1=reshape(0:1,2,1); U2=reshape(0:1,2,1); U3=reshape(0:1,2,1);
    R1=reshape(0:1,2,1); R2=reshape(0:1,2,1); R3=reshape(0:1,2,1);
    %get mode shape - need to format output once we talk to Tracy about this:
    [ret,~,~,~,~,~,~,U1,U2,U3,R1,R2,R3] = SapModel.Results.ModeShape(Name, GroupElm, NumberResults, Obj, Elm, LoadCase, StepType, StepNum, U1, U2, U3, R1, R2, R3);
    Phi(b,1)=U1(ModeShape1);
    Phi(b,2)=U2(ModeShape2);
end

%Output:
%(1)ret (2)NumberofModes (3)PointName (4)PointName (5)StepType (6)
%NumberofModesConsidered
%is ordered such that U1,U2,etc is provided for each Point for each
%mode: (e.g. U1: Cols 1:12 correspond to Node 1, Cols 13:25 correspond to
%Node 2)

%Note: will probably have to create node group in order to filter through
%results.

%% Save ELF model and iterate over all intensities:
%save .sdb file as another model (this helps us keep track of our models): 
tag2='_ELFM.sdb'; %this first tag is simply so we can make sure that this model gets saved (needs the .sdb for this to happen)
FileName=strcat(FilePathResponse,tag2); 
SapObject.SapModel.File.Save(FileName);
%Final step:Close out of SAP:
SapObject.ApplicationExit(false());
SapModel=0;
SapObject=0;

end

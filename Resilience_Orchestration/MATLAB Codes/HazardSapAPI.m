%% SAP2000 Script - API integration
%Hazard Module

%This script performs the following operations:
%(1) Establishes element connectivity
%(1a) For frame elements: connectivity between frame, joint, joint
%coordinates
%(1b) For area elements: connectivity between area element (floor or
%wall) and the joints which create the element

%(2) Assigns fixed-base boundary conditions to the ends of all columns at
%the base of the structure

%(3) Assigns rigid diaphragm constraint to all joints at floor slab
%elevations (elevations obtained from Revit)

%(4) Runs a modal analysis
%(4a) Assigns mass source as 1.0DL+0.3LL
%(4b) Provides period in x and y directions (we assume uncoupled) and
%eigenvalues
%(4c) Provides values for modal participation factors, modal participating
%mass ratios, modeshape (right now it is 3D)
%(4d) Mass per floor and Total mass

%% Input/Output for HazardSapAPI

function [FrameObjNames,JointCoords,FrameJointConn,FloorConn,WallConn,T1x,T1y,mass_floor,weight,FilePathResponse]=HazardSapAPI(FilePath,units,elev,frame_wall_flag,struct_wall_flag,wall_type,E,u,a)
%-------------------------------------------------------------------------%
%Input
%FilePath: string with path to file
%e.g. FilePath = 'D:\Users\Karen\Documents\Revit 2017\RC_FRAME_FRAME_AND_FLOORS';

%units: double with value 1 to 16
%lb,in,F=1  lb,ft,F=2   kip,in,F=3  kip,ft,F=4
%kN,mm,C=5  kN,m,C=6    kgf,mm,C=7  kgf,m,C=8
%N,mm,C=9   N,m,C=10    Ton,mm,C=11 Ton,m,C=12
%kN,cm,C=13 kgf,cm,C=14 N,cm,C=15   Ton,cm,C=16

%elev: vector of floor elevations

%-------------------------------------------------------------------------%
%Output
%FrameObjNames: List of Names of Frames Members (strings) - these are
%needed to run the ResponseSapAPI.m file

%JointCoords: nx4 matrix - Col1==Joint Number, Col2to4==(x,y,z) in GCS

%FrameJointConn: nx9 matrix - Col1==FrameName, Col2==iend joint number, Col3to5 (x,y,z) of
%iend joint in GCS, Col6==jend joint number, Col7to9 (x,y,z) of jend joint
%in GCS

%Floor Conn: matrix - Col1==FloorName Col2:n --> joint numbers which
%correspond to that floor

%WallConn: matrix - Col1==WallName Col2:n --> joint numbers which
%correspond to that wall

%T1x, T1y: first fundamental periods in the x and y, respectively

%mass_floor: vector with mass per floor starting from floor 1 to roof

%weight: total weight of structure for 1.0DL+0.3LL load case (used for modal
%analysis as well)

%FilePathResponse: file path to full SAP model with boundary conditions and
%modal analysis which will be used for the Response Module

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
%FilePath = 'D:\Users\Karen\Documents\Revit 2017\RC_FRAME_FRAME_ONLY'; % Location of Sap2000 Model *this is an example 
SapModel.File.OpenFile([FilePath,'.sdb']); 

%% Edit Model 
% ---------- 
% Model lock =>(1)or unlock =>(0) 
SapModel.SetModelIsLocked(0);

%switch to specified units:
ret = SapModel.SetPresentUnits(units);

%create the analysis model
ret = SapModel.Analyze.CreateAnalysisModel;

%% Joint Coordinate Information
%This section figures out how many point elements are in our SAP model and
%then creates a matrix ordered as follows:
%Cols 1:4 --> PointName,x,y,z

%-------------------------------------------------------------------------%
%Get joint coordinates:
%Count the number of point elements:
PointCount=SapModel.PointElm.Count;

%Get cartesian point element coordinates
%Initialize variables
xcoords=zeros(PointCount,1);
ycoords=zeros(PointCount,1);
zcoords=zeros(PointCount,1);
for i=1:PointCount
    PointNum=num2str(i);
    x=1;y=1;z=1; %dummy values of 1
    [ret,x,y,z] = SapModel.PointElm.GetCoordCartesian(PointNum, x, y, z,'Global');
    xcoords(i)=x;
    ycoords(i)=y;
    zcoords(i)=z;
end

%Matrix of Joint Numbers and Corresponding Coordinates in (x,y,z): Matrix
%coincides with presentation in Joint Coordinates Table in SAP2000
JointCoords=[[1:PointCount]' xcoords ycoords zcoords];


%% Connectivity information: Frames and Joints
%This section maps frame element ID numbers to their corresponding joints
%and coordiantes in the global coordinate system:
if frame_wall_flag==0 && struct_wall_flag==0 %First we need to figure out if there are frame elements present. Is this a wall structural system?: 0==false 1==true

%-------------------------------------------------------------------------%      
%Count how many line (frame) elements are available:
FrameCount=SapModel.LineElm.Count;
NumberNames=FrameCount; %Number of Frame Names one wants
MyName=cellstr(''); %dummy empty cell

%Get frame object names:
%Ouput:
%ret=0 if successfully executed
%NumberFrameObjects should be equal to FrameCount
%FrameObjNames: String List of Frame ID #s in the order of the Connectivity
%- Frame Table in the Export Options for SAP2000 (cell type)
[ret,NumberFrameObjects,FrameObjNames]=SapModel.FrameObj.GetNameList(NumberNames,MyName);


%-------------------------------------------------------------------------%
%Get names of points attached to each frame element:
%Initialize variables:
iend=zeros(FrameCount,1);
jend=zeros(FrameCount,1);
for j=1:FrameCount
    FrameName=char(FrameObjNames(j));
    PointName1 = ' ';
    PointName2 = ' ';
    [ret, PointName1, PointName2] = SapModel.FrameObj.GetPoints(FrameName, PointName1, PointName2);
    iend(j)=str2num(PointName1);
    jend(j)=str2num(PointName2);
end

%-------------------------------------------------------------------------%
%Establish Connectivity between frame elements, joints, and coordinate
%locations:
%Matrix is ordered such that: 
%FrameJointConn=[FrameID# Point1(iend) x y z Point2(jend) x y z]
%Size of FrameJointConn=(8,1)
FrameJointConn=zeros(FrameCount,8);
FrameJointConn(:,1)=str2num(char(FrameObjNames)); %Frame ID # Column
FrameJointConn(:,2)=iend; %Node I column
FrameJointConn(:,6)=jend; %Node J column
FrameJointConn([1:FrameCount]',[3:5])=JointCoords(iend([1:FrameCount]'),(2:4)); %(x,y,z) of Node I
FrameJointConn([1:FrameCount]',[7:9])=JointCoords(jend([1:FrameCount]'),(2:4)); %(x,y,z) of Node J

else
    FrameObjNames=0;
    FrameJointConn=0;
end

%% Connectivity Information: Floors:
AreaCount = SapModel.AreaObj.Count;
NumberNames=AreaCount; %Number of Area Names one wants
MyName=cellstr(''); %dummy empty cell

%Get area object names:
%Ouput:
%ret=0 if successfully executed
%NumberAreaObjects should be equal to AreaCount
%AreaObjNames: String List of Area ID #s in the order of the Connectivity
%- Area Table in the Export Options for SAP2000 (cell type)
%Note: SAP considers floors and walls area elements so these are sorted out
%later
[ret,NumberAreaObjects,AreaObjNames]=SapModel.AreaObj.GetNameList(NumberNames,MyName);

%-------------------------------------------------------------------------%
%Get names of points attached to each area element:
%Initialize variables:

AreaTag=zeros(AreaCount,1); %Holder variable which will idicate if area element is floor (==1) is wall (==0)

for p=1:AreaCount
    AreaName=char(AreaObjNames(p));
    NumberPoints=1; %dummy value
    MyPoints=cellstr('');
    [ret,NumberofPoints,ListofPoints] = SapModel.AreaObj.GetPoints(AreaName, NumberPoints, MyPoints);
    %ListofPoints gives us all of the points associated with that specific
    %area element
    
    %Figure out if this is a floor or wall:
    Points=str2num(char(ListofPoints));
    zPoints=zcoords(Points);
    if min(zPoints)==max(zPoints) %basically here we are saying that if all points are at the same elevation, then it is a floor
        AreaTag(p,:)=1;
    else 
        AreaTag(p,:)=0;
    end
    AreaJoints(p,[1:length(ListofPoints)])=str2num(char(ListofPoints));
end


%Area connectivity, as presented in Connectivity-Area table in SAP2000
%Order of matrix: Col1:Area Object Names, Rows(2:n):Joints that are a part of that area element 
if AreaCount==0
    AreaJoints=0;
else
    a=0;
end
AreaConn=[AreaTag str2num(char(AreaObjNames)) AreaJoints]; %(doubles)

%Floor-Joint and Wall-Joint Connectivity
FloorConn=AreaConn(find(AreaTag==1),2:end);
WallConn=AreaConn(find(AreaTag==0),2:end);

%% Assign boundary conditions at the bottom of column/wall elements at the base of the structure:

%Figure out which points need a restraint:
%JointRes is the name of an existing point object
%Restaint - vector of logicals refers to the 6 possible constraints 
%(U1,U2,U3,R1,R2,R3). 1=true 0=false

%Set up fixed boundary condition:
Restraint= true(6,1);

for h=1:PointCount
    if JointCoords(h,4)==min(zcoords);
        JointRes=num2str(JointCoords(h,1));
        ret = SapModel.PointObj.SetRestraint(JointRes,Restraint);
    else
        a=1; %this is just a dummy value
    end
end

%% Wall Structural Systems:
%For wall structural systems, we have to assign material properties and
%sections to the respective area elements. (The CSiXRevit converter imports
%wall elements as shell elements with none properties.)

thickness=3+(5/8);
if struct_wall_flag==1
    %First we are going to define a new material:
    ret=SapModel.PropMaterial.SetMaterial(wall_type,3);
    %Now we assign isotropic mechanical properties:
    ret = SapModel.PropMaterial.SetMPIsotropic(wall_type,E,u,a);
    %Create a new area section to overwrite the "None" one:
    ret = SapModel.PropArea.SetShell('WallSection', 1, wall_type, 0, thickness, thickness);
    %Assign section to wall area objects:
    for i=1:length(WallConn(:,1))
        WallName=num2str(WallConn(i,1));
        ret = SapModel.AreaObj.SetProperty(WallName, 'WallSection');
    end
else
end

%% Assign diaphragm boundary condition:
%In order to assign this boundary condition we need to know where the
%different heights of the floor slabs are (regardless if SAP model supplied
%does or does not have floors on it:
%elev=elev*12; %This is just here to make sure we are in the right units
%We pull floor elevation from the outside (Python): elev variable

%First define how many diaphragm constraints are needed:
for c=1:length(elev)-1
    %Name of Diaphragm Constraint:
    DiaphName='Diaph%d';
    DNumber=c;
    Diaph=sprintf(DiaphName,DNumber); 
    %define a new constraint:
    ret = SapModel.ConstraintDef.SetDiaphragm(Diaph,3); %set the diaphragm constraint in the z axis
end

%define new constraint assignments
for d=1:length(elev)-1
   %Choose points which will be a part of the diaphragm constraint:
   PointsD=find(round(zcoords)==elev(d+1));
   %Name of Diaphragm Constraint:
    DiaphName='Diaph%d';
    DNumber=d;
    Diaph=sprintf(DiaphName,DNumber); 
   for p=1:length(PointsD)
        ret = SapModel.PointObj.SetConstraint(num2str(PointsD(p)), Diaph,0); %look up constraint function 
   end
end
% %This option here is if we are only assigning diaphragm constraint to nodes
%associated with the outer border of the floors:
%Also, if in the future we decide to do something fancier with semi-rigid
%diaphgrams, the following function will be useful:
%ret = SapModel.NamedAssign.ModifierArea.SetModifiers("AMOD1", Value)

% %Amount of floors:
% FloorCount=length(find(AreaTag==1));
% 
% for c=1:FloorCount
%     %Name of Diaphragm Constraint:
%     DiaphName='Diaph%d';
%     DNumber=c;
%     Diaph=sprintf(DiaphName,DNumber); 
%     %define a new constraint:
%     ret = SapModel.ConstraintDef.SetDiaphragm(Diaph,3); %set the diaphragm constraint in the z axis
% end
% 
% %define new constraint assignments
% for d=1:FloorCount
%    %Choose points which will be a part of the diaphragm constraint:
%    PointsD=FloorConn(d,[2:end]);
%    %Name of Diaphragm Constraint:
%     DiaphName='Diaph%d';
%     DNumber=d;
%     Diaph=sprintf(DiaphName,DNumber); 
%    for p=1:length(PointsD)
%         ret = SapModel.PointObj.SetConstraint(num2str(PointsD(p)), Diaph,0); %look up constraint function 
%    end
% end

%% Run Modal Analysis:
%A modal load case was automatically created when the .exr file was
%converted to a .sdb file, so there is no need to define a modal load case
%for this part of the analysis.

%-------------------------------------------------------------------------%
%First we need to set up modal mass:
%add a new mass source and make it the default mass source

%Get Load Pattern Names:
NumberNames=2;
MyList=cellstr('');
[ret,NumofPat,LoadPatNames]=SapModel.LoadPatterns.GetNameList(NumberNames,MyList);

%Set up Mass Source:
%SetMassSource inputs:
%(1) Name of mass source (string)
%(2) If this item is true then element self mass is included in the mass
%(3) If this item is true then assigned masses are included in the mass
%(4) If this item is true then speficied load patterns are included in the
%mass
%(5) If this item is true then the mass source is the defualt mass source.
%(6) Number of Loads specified for the mass source (only applicable if (4) is true
%(7) LoadPatNames - This is an array of load pattern names specified for the
%mass source
%(8) Multipliers - This is an array of load pattern names specified for the
%mass source.
Multipliers=[1;0.3]; %NOTE: we may need to change these in the future if we work with other codes/standards
ret = SapModel.SourceMass.SetMassSource('MSSSRC1', false(), true(), true(), true(), 2, LoadPatNames, Multipliers);

%Run model (this will create the analysis model)
ret = SapModel.Analyze.RunAnalysis();
ret = SapModel.Results.Setup.DeselectAllCasesAndCombosForOutput;
ret = SapModel.Results.Setup.SetCaseSelectedForOutput('MODAL');


%% Get Sap2000 results - Modal Analysis
%-------------------------------------------------------------------------%
%Extract Period, Eigenvalues
NumberResults=1;
LoadCase=cellstr('');
StepType=cellstr('');
StepNum = reshape(0:1,2,1);
Period = reshape(0:1,2,1);
Frequency = reshape(0:1,2,1);
CircFreq = reshape(0:1,2,1);
EigenValue = reshape(0:1,2,1);

%Omitted outputs (in order):
%NumberofModes,LoadCase,StepType,ModeNumber

[ret,~,~,~,~,Period,Frequency,CircFreq,EigenValue]  = SapModel.Results.ModalPeriod(NumberResults,LoadCase,StepType,StepNum,Period,Frequency,CircFreq,EigenValue);


%-------------------------------------------------------------------------%
%Modal Participation Factors:
NumberResults=1;
LoadCase=cellstr('');
StepType=cellstr('');
StepNum = reshape(0:1,2,1);
Period = reshape(0:1,2,1);
Ux=reshape(0:1,2,1); Uy=reshape(0:1,2,1); Uz=reshape(0:1,2,1);
Rx=reshape(0:1,2,1); Ry=reshape(0:1,2,1); Rz=reshape(0:1,2,1);
ModalMass=reshape(0:1,2,1); ModalStiff=reshape(0:1,2,1);

%Omitted outputs (in order):
%NumberofModes,LoadCase,StepType,ModeNumber
[ret,NumberofModes,~,~,~,~,Ux,Uy,Uz,Rx,Ry,Rz,ModalMass,ModalStiff] = SapModel.Results.ModalParticipationFactors(NumberResults, LoadCase, StepType, StepNum, Period, Ux, Uy, Uz,Rx, Ry, Rz, ModalMass, ModalStiff);

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

%Figure out which fundamental mode corresponds to the x and y directions:
for t=1:NumberofModes
    if Ux(t)==max(Ux)
        T1x=Period(t);
    else
        a=0;
    end
    if Uy(t)==max(Uy)
        T1y=Period(t);
    else
        b=0;
    end
end

%-------------------------------------------------------------------------%
%Modeshape: %Look at GetOptionModeShape possibly - Lets you figure out
%which mode shapes you want
Name='ALL';
GroupElm=2;
NumberResults=1;
Obj=cellstr('');
Elm=cellstr('');
LoadCase=cellstr('');
StepType=cellstr('');
StepNum = reshape(0:1,2,1);
U1=reshape(0:1,2,1); U2=reshape(0:1,2,1); U3=reshape(0:1,2,1);
R1=reshape(0:1,2,1); R2=reshape(0:1,2,1); R3=reshape(0:1,2,1);
%get mode shape - need to format output once we talk to Tracy about this:
ret = SapModel.Results.ModeShape(Name, GroupElm, NumberResults, Obj, Elm, LoadCase, StepType, StepNum, U1, U2, U3, R1, R2, R3);

%Output is ordered such that U1,U2,etc is provided for each Point for each
%mode: (e.g. U1: Cols 1:12 correspond to Node 1, Cols 13:25 correspond to
%Node 2)

%Note: will probably have to create node group in order to filter through
%results.

%% Mass per floor:
%We assume that the load combination was already set up in Revit: 
%MassCombo=1.0DL+0.3LL
%Select which combo we are pulling information from:
ret = SapModel.Results.Setup.DeselectAllCasesAndCombosForOutput;
ret = SapModel.Results.Setup.SetComboSelectedForOutput('MassCombo');

%Find the assembled joint masses for all points:
GroupElm=2;
NumberResults=0;
PointElm=cellstr('');
U1=reshape(0:1,2,1); U2=reshape(0:1,2,1); U3=reshape(0:1,2,1);
R1=reshape(0:1,2,1); R2=reshape(0:1,2,1); R3=reshape(0:1,2,1);
%get assembled joint mass for all point elements:
%Omitted output:
%(1) NumberofPoints
%(2) PointNames
[ret,~,~,U1] = SapModel.Results.AssembledJointMass('ALL', GroupElm, NumberResults, PointElm, U1, U2, U3, R1, R2, R3);
%U1 is a horizontal vector with the mass per joint as ordered in the
%connectivity done at the beginning of this script

%Now let's calculate mass per floor:
mass_floor=zeros(length(elev)-1,1); %vector of mass per floor listing masses from the bottom up

for d=1:length(elev)-1
   %Choose points which will be a part of the diaphragm constraint:
   PointsMass=find(round(zcoords)==elev(d+1)); 
   %We now have the points which are all on this floor
   %Calculate total mass per floor:
   mass_floor(d,:)=sum(U1(PointsMass));   %if we are working in kip-in, then this will be in kip-s^2/in
end


%% Next up - extract total mass
%We assume that the load combination was already set up in Revit: 
%MassCombo=1.0DL+0.3LL

ret = SapModel.Results.Setup.DeselectAllCasesAndCombosForOutput;
ret = SapModel.Results.Setup.SetComboSelectedForOutput('MassCombo');

%Figure out which nodes are at the base:
Base=JointCoords([1:PointCount],4)==min(zcoords);
BaseJoints=JointCoords(find(Base),1);
zreaction=zeros(length(BaseJoints),1);

for n=1:length(BaseJoints)
    PointName=num2str(BaseJoints(n,:));
    Element=0;
    NumberResults=1;
    Obj=cellstr('');
    Elm=cellstr('');
    LoadCase=cellstr('');
    StepType=cellstr('');
    StepNum = reshape(0:1,2,1);
    F1=reshape(0:1,2,1); F2=reshape(0:1,2,1); F3=reshape(0:1,2,1);
    M1=reshape(0:1,2,1); M2=reshape(0:1,2,1); M3=reshape(0:1,2,1);
    %Output - (1) NumberofJoints (2)JointName (3)JointName (4) LoadCase
    %(5){''} (6)0 (7) F1 (8)F2 (9) F3 (10)M1 (11)M2 (12) M3
    %get base joint reactions
    [ret,~,~,~,~,~,~,~,~,F3,~,~,~] = SapModel.Results.JointReact(PointName,Element,NumberResults, Obj,Elm,LoadCase, StepType, StepNum, F1, F2, F3, M1, M2, M3);

    zreaction(n,:)=F3;

end

weight=sum(zreaction);

%%
% %% Axial Forces: Let's pull out axial forces in frame members (this is for later in case we decide we need this for the fragility curves):
% %We assume that the load combination was already set up in Revit: 
% %MassCombo=1.0DL+0.3LL
% ret = SapModel.Results.Setup.DeselectAllCasesAndCombosForOutput;
% ret = SapModel.Results.Setup.SetComboSelectedForOutput('MassCombo');
% 
% %Get frame forces:
% %Initialize variables:
% iaxial=zeros(FrameCount,1); %create a vector to store axial forces on i-end of frame
% jaxial=zeros(FrameCount,1); %create a vector to store axial forces on j-end of frame
% 
% for j=1:FrameCount
%     FrameName=char(FrameObjNames(j));
%     ObjectElm=0;
%     NumberResults=0;
%     Obj=cellstr('');
%     Elm=cellstr('');
%     PointElm=cellstr('');
%     LoadCase=cellstr('');
%     StepType=cellstr('');
%     StepNum = reshape(0:1,2,1);
%     F1=reshape(0:1,2,1); F2=reshape(0:1,2,1); F3=reshape(0:1,2,1);
%     M1=reshape(0:1,2,1); M2=reshape(0:1,2,1); M3=reshape(0:1,2,1);
%     
% %Omitted output:
% %(1) number of objects info is returned for: 2
% %(2 and 3) FrameName
% %(4) Frame Points: i-end, j-end
% %(5) LoadCase
% %(6) '''' (InputPointNames)
% %(7) 0 0
% %(8) V3 (9) V2 (10) M3 (11) M2
% %note: SAP interprets axial depending on what axis the member is in:
% %i.e. columns - axial is considered in the vertical direction
% %beams - axial is considered in the horizontal direction
%     [ret,~,~,~,~,~,~,~,~,~,Axial,~,~] = SapModel.Results.FrameJointForce(FrameName, ObjectElm, NumberResults, Obj, Elm, PointElm, LoadCase, StepType, StepNum, F1, F2, F3, M1, M2, M3) ;
%     iaxial(j,:)=Axial(1);
%     jaxial(j,:)=Axial(2);
% end
% 
% %Give me a matrix that lists the following (and in order):
% %(1) Column FrameName (2)i-end point (3)axial force (4)j-end point (5)axial force
% FrameReactions=[FrameJointConn(:,1) iend iaxial jend jaxial];

%% Final step: Close out of SAP:
%save .sdb file as another model (this helps us keep the original, no BCS model):
tag2='_Modal.sdb'; %this first tag is simply so we can make sure that this model gets saved (needs the .sdb for this to happen)
tag_Response='_Modal'; %this is being added here so that we can pass the model to the ResponseSapAPI.m script later
FilePathResponse=strcat(FilePath,tag_Response); %this is the name that will be provided as input for the ResponseSapAPI.m script
FileName=strcat(FilePath,tag2); 
SapObject.SapModel.File.Save(FileName);

SapObject.ApplicationExit(false());
SapModel=0;
SapObject=0;

end
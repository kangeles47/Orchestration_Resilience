function [FrameObjNames,JointCoords,FrameJointConn,FloorConn,WallConn,T1,hj,mass_floor,weight,Sw,FilePathResponse,lfm,Dl,Sax,Say,Fj,PGA,Sa_1]=InitHazardModule(FilePath,units,elev,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,num_int,frame_wall_flag,struct_wall_flag,wall_type,E,u,a)

%% Initialization Script for MATLAB side of the Hazard Module:

%This function combines MATLAB scripts which conduct a modal analysis and
%use this information, along with hazard data from USGS (using Python), to
%calculate equivalent static forces for a given building. A description of
%each function follows, along with more details of each function's input/output:

%Contents of script:
%(1)HazardSapAPI function --> Connectivity data, modal analysis
%information, file name of SAP model for Response Module

%(2) time_based_assessment function --> establishes spectral accelerations
%in the x and y directions, finds their corresponding annual rate of
%exceedance, and probability of failure.

%(3)equiv_static_forces function --> Matrix of equivalent static forces for
%the specified hazard for a given building. Note: Version 2 - ESFs are
%normalized so that they can be scaled based on base shear value


%% Input/output variables to execute HazardSapAPI:
%Input
%FilePath: string with path to file
%e.g. FilePath = 'D:\Users\Karen\Documents\Revit 2017\RC_FRAME';

%units: double with value 1 to 16
%lb,in,F=1  lb,ft,F=2   kip,in,F=3  kip,ft,F=4
%kN,mm,C=5  kN,m,C=6    kgf,mm,C=7  kgf,m,C=8
%N,mm,C=9   N,m,C=10    Ton,mm,C=11 Ton,m,C=12
%kN,cm,C=13 kgf,cm,C=14 N,cm,C=15   Ton,cm,C=16
%e.g. units=3;

%elev: vector of floor elevations **Make sure that these are in the same
%units as specified in the variable units** These are being taken from the
%Semantic Graph developed in Python (GeoLinked)
%e.g elev=[0;120;240];

%-------------------------------------------------------------------------%
%Call the function for the respective SAP model:
[FrameObjNames,JointCoords,FrameJointConn,FloorConn,WallConn,T1x,T1y,mass_floor,weight,FilePathResponse]=HazardSapAPI(FilePath,units,elev,frame_wall_flag,struct_wall_flag,wall_type,E,u,a);

%Output
%FrameObjNames: List of Names of Frames Members (strings) - these are
%needed to run the ResponseSapAPI.m file

%JointCoords: nx4 matrix - Col1==Joint Number, Col2to4==(x,y,z) in GCS

%FrameJointConn: nx9 matrix - Col1==FrameName, Col2==iend joint number, Col3to5 (x,y,z) of
%iend joint in GCS (Global Coordinate System), Col6==jend joint number, Col7to9 (x,y,z) of jend joint
%in GCS

%Floor Conn: matrix - Col1==FloorName Col2:n --> joint numbers which
%correspond to that floor

%WallConn: matrix - Col1==WallName Col2:n --> joint numbers which
%correspond to that wall

%T1: 1x2 vector with entries [T1x T1y]

%mass_floor: total mass per floor of structure for 1.0DL+0.3LL load case (used for modal
%analysis as well)

%% Input/Output for time_based_assessment
%***Description of what this function does here***
%We have to implement a small correction to the values we get back from USGS:
%The issue is that in order to use the interp1 function in MATLAB, vectors
%need to be monotonically increasing. This is not always the case for the
%values we get from USGS. The following if statements simply check if there
%are repeating zero values for spectral acceleration. If there is, we
%modify our vectors. If not, we leave them alone.

if length(find(~PGAy))>1
    PGAx=PGAx(1:find(~PGAy,1));
    PGAy=PGAy(1:find(~PGAy,1)); %This is a simple query to make sure that we do not have repeating zero values
end

if length(find(~SA1y,1))>1
    SA1x=SA1x(1:find(~SA1y,1));
    SA1y=SA1y(1:find(~SA1y,1)); %This is a simple query to make sure that we do not have repeating zero values
end

if length(find(~SA02y))>1
    SA02x=SA02x(1:find(~SA02y,1));
    SA02y=SA02y(1:find(~SA02y,1)); %This is a simple query to make sure that we do not have repeating zero values
end

%Here we are calculating stuff for all intensities: ask how this is
%affecting input to ESFs function:
[lfm,Dl,Sax,Say,PGA,Sa_1]=time_based_assessment(T1x,T1y,num_int,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y);

%% Input/Output for equiv_static_forces
%This function calculates equivalent lateral forces:

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Input%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%T1: fundamental period of structure(in sec) in x and y direction respectively
%Sa(T1): in g is the 5% damped spectral acceleration at the fundamental period,in x and y direction respectively
%Sw: in kips, is the lumped seismic weight at each floor(1;2;3;...etc)
%W: in kips, total weight of structure
%Vy: in kips, estimated yield base shear from Nonlinear Static Analysis,in x and y direction respectively
%Phi: vector of fundamental modeshapes,in x(first column) and y(second column) direction
%hj: elevation(in ft) of each floor

%Floor elevations:
hj=elev(2:end)';

%Define vector of periods from modal analysis:
T1=[T1x T1y];

%Define Sw - the lumped seismic weight of each floor:
Sw=mass_floor*386;

%Define total weight of structure:
W=weight;

%Calculation of Equivalent Lateral Forces(matrix:first column x, second column y, rows:floor number
%These forces are used to get preliminary displacements which are later
%scaled according to intensity.
Fj=zeros(length(hj),2);
for i=1:2
    if T1(i)<0.5
         k=1;
       elseif T1(i)>2.5
        k=2;
       else
        k=0.75+0.5*T1(i);
    end
    Fj(:,i)=(Sw.*hj.^k)/sum(Sw.*hj.^k);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Output%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Calculation of Equivalent Lateral Forces(matrix:first column x, second column y, rows:floor of stories%%%%%%%%

%% End of Hazard Module
end
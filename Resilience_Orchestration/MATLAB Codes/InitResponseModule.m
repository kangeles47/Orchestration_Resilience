function [x_disp,y_disp,m_drift_ratios,m_vel_ratios,m_accel,b_SD,b_FA,b_FV,b_RD,Cost]=InitResponseModule(FrameObjNames,units,FilePathResponse,elev,Fj,num_int,T1,hj,g,PGA,Sa_1,Sax,Say,lfm,Frame_type,Soil_Site_class,Sw,weight)
%% Initialization Script for MATLAB side of the Response Module:

%This function combines MATLAB scripts which conduct analyses using the
%ELFM (Equivalent Lateral Force Method) for num_int number of intensities,
%as defined in the Hazard Module. Displacements are obtained at the
%centroid of each floor for loading in the x and y directions. Corrections
%are implemented as per FEMA Simplified Analysis Procedures. 

%Contents of script:
%(1)ResponseSapAPI function--> Finds x and y centroid of the structure, applies
%ELFM, calculates structure's response

%(2) mean_dispersion function -->
%% Input/Output for ResponseSapAPI

%Input:
%FrameObjNames - list of names of frame members from HazardSapAPI.m
%units - same as in HazardSapAPI.m
%FilePathResponse - this will be the name of that from the HazardSapAPI.m model at
%the end
%elev - vector of elevations beginning from z=0 to roof
%Fj - matrix of ELFs for the num_int number of intensities specified in the
%Hazard Module
%num_int - number of intervals as defined in previous module

%Note: This script was modified so that we can run all iterations of our
%ELFs without having to open and close SAP each time (saves time)

[x_disp,y_disp,Joint_elev,JointNames,Gamma,Phi]=ResponseSapAPI(FrameObjNames,units,FilePathResponse,elev,Fj);
disp=[x_disp y_disp];


%Outputs: Ux,Uy --> nx1 vectors of displacements at the centroid of each floor for the x and y directions for
%each set of ELFs. 

%Joint_elev: z-coordinate of respective joint specified in JointNames

%JointNames: Names of newly defined points at floor centroids for ELFM

%% Input/Output for median_dispersions function:
%Calculation of Median responses and Dispersions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Input%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%N: number of stories
%T1: fundamental period of structure(in sec) in x and y direction respectively
%Vy: in kips, estimated yield base shear from Nonlinear Static Analysis,in x and y direction respectively
%hj: height(in ft) of each floor
%g: acceleration of gravity(determines the units of displacement and of
%velocity)
%PGA: Peak ground aceeleration in g
%Sa_1: Spectral acceleration at a period of 1.0 sec,in g
%Gamma: modal participation factors of the fundamental mode,in x and y direction respectively
%Frame type: Braced, Moment or Wall
%disp_x,disp_y Median displacement in x and y direction(from Linear analysis/vectors:from down to upper floors)

%Soil_Site_class: A,B,C,D,E from ASCE/SEI 7-10 characterization
%Given a site class, figure out what our value for a is:
switch Soil_Site_class
    case 'A'
        a=130;
    case 'B'
        a=130;
    case 'C'
        a=90;
    case 'D'
        a=60;
    otherwise
        a=60;
end

%Frame type: Braced, Moment or Wall
%Given a framt type, calculate value for p:
switch Frame_type
    case 'Braced'
        p=1;
    case 'Moment'
        p=2;
    case 'Wall'
        p=3;
end

%Coefficients FEMA P-58
if length(hj)<=9
    CF=importdata('CF_9.mat');
else
    CF=importdata('CF_15.mat');
end

Data=load('Modal_disp.mat');%remove this(contains modeshapes, modal participating mass ratios and displacement due to Fj)
Vy=[10000,10000];%in kips, estimated yield base shear from Nonlinear Static Analysis,in x and y direction respectively

%calculations for W1(first mode effective weight)
W1=zeros(1,2);
for i=1:2    
    W1(i)=(sum(Sw'*Phi(:,i))).^2/(sum(Sw'*Phi(:,i).^2));
    if W1(i)<0.8*weight
        W1(i)=0.8*weight;
    end
end

%Loop for different intensities
j=1;
b_SD=zeros(length(num_int),2);
b_FA=zeros(length(num_int),2);
b_FV=zeros(length(num_int),2);


Na=2;%number of damage assemblies

theta=[0.4 2.26 2.67;0.0175 0.0225 0.0322];%median values of the two different fragility
%curves used(each row has the median values of the 3 damage
%stages[D1,D2,D3].First row:Exterior wall/Second row: OMF).

beta=[0.4 0.3 0.25;0.4 0.4 0.4];%dispersion of the the two different fragility
%curves used.(each row has the dispersions of the 3 damage
%stages[D1,D2,D3].First row:Exterior wall/Second row: OMF).

RC=[1776.67 3720 5460;27846 38978.4 47978.4];%cost of the the two different fragility
%curves used.(each row has the average cost of the 3 damage
%stages[D1,D2,D3].First row:Exterior wall/Second row: OMF).

quant=[8,4];%quantity of each damage assembly

Nz=1000;

for i=1:num_int
    Sa=[Sax(i),Say(i)];
    [m_drift_ratios(:,j:j+1),m_vel_ratios(:,j:j+1),m_accel(:,j:j+1),b_SD(i,:),b_FA(i,:),b_FV(i,:),b_RD]=median_dispersions(T1,Vy,hj,g,Sa,PGA(i),Sa_1(i),Gamma,p,CF,disp,W1,weight);
    for k=1:2
    Cost(:,k+(j-1))=calc_losses(m_drift_ratios(:,k+(j-1)),b_SD(i,k),beta,theta,Nz,RC,Na,quant);
    end
    j=j+2;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Output%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Calculation of Median responses and Dispersions for x and y direction



end
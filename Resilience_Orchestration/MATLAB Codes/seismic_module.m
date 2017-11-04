%Seismic Performance Assessment of Buildings

%Prior to this point of the alforithm, we have to conduct modal analysis
%of the structure and get T1x, T1y, Phi:modeshapes in x and y direction
%(for only the fundamental period) and Gamma:modal participating mass ratios.
%(store all these variables globally)

% Also, we have to exctract all the information from USGS, regarding the
% hazard curves.(store globally)

load('USGS_modal.mat')%remove this when we have the USGS module ready and have the values of the modal analysis


m=8;%the user must provide this value;This is the number of intervals that the
    %hazard curve will have.

%%%%%%%%%Time based assessments:split hazard curve of site in m intervals%%%%%

%lfm:annual frequency of exceedance of the midpoint spectral acceleration
%for each interval.
%Dl:mean annual probability of occurrence of ground motions within an
%interval.
%for each lfm we find Sax=Sa(T1x) and Say=Sa(T1y)
%for each lfm we find PGA and Sa(T=1 sec)
[lfm,Dl,Sax,Say,PGA,Sa_1]=time_based_assessment(T1x,T1y,m,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y);

%%%%%%%%%Calculation of the Vertical distribution of the Equivalent Lateral Forces

%Vertical Distribution of Lateral Forces

Sw=[56.4 37.6];%%Sw: in kips, is the lumped seismic weight at each floor(1;2;3;...etc)
W=95;%W: in kips, total weight of structure
hj=[10;20];%hj: elevation(in ft) of each floor
%Remove Sw and hj and replace them with the actual values from python

T1=[T1x T1y];
Fj=zeros(length(hj),2);
for i=1:2
    if T1(i)<0.5
         k=1;
       elseif T1(i)>2.5
        k=2;
       else
        k=0.75+0.5*T1(i);
    end
    Fj(:,i)=(Sw.*hj'.^k)/sum(Sw.*hj'.^k);
end

%Right here, we calculate the response of the building using SAP2000
%We extract the displacements of the centroid of each floor in x and y
%direction.

%Soil_Site_class: A,B,C,D,E from ASCE/SEI 7-10 characterization
Soil_Site_class='B';%the user must provide this value

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
Frame_type='Moment';%the user must provide this value

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

load('Modal_disp.mat')%remove this(contains modeshapes, modal participating mass ratios and displacement due to Fj)
Vy=[10000,10000];%in kips, estimated yield base shear from Nonlinear Static Analysis,in x and y direction respectively
g=32.174;%acceleration of gravity(determines the units of displacement and of

%calculations for W1(first mode effective weight)
W1=zeros(1,2);
for i=1:2    
    W1(i)=(sum(Sw'.*Phi(:,i))).^2/(sum(Sw'.*Phi(:,i).^2));
    if W1(i)<0.8*W
        W1(i)=0.8*W;
    end
end

%Loop for different intensities
j=1;
b_SD=zeros(length(m),2);
b_FA=zeros(length(m),2);
b_FV=zeros(length(m),2);

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

for i=1:m
    Sa=[Sax(i),Say(i)];
    [m_drift_ratios(:,j:j+1),m_vel_ratios(:,j:j+1),m_accel(:,j:j+1),b_SD(i,:),b_FA(i,:),b_FV(i,:),b_RD]=median_dispersions(T1,Vy,hj,g,Sa,PGA(i),Sa_1(i),Gamma,p,CF,disp,W1,W);
    
    for k=1:2
    Cost(:,k+(j-1))=calc_losses(m_drift_ratios(:,k+(j-1)),b_SD(i,k),beta,theta,Nz,RC,Na,quant);
    end
    j=j+2;
end



function [m_drift_ratios,m_vel_ratios,m_accel,b_SD,b_FA,b_FV,b_RD]=median_dispersions(T1,Vy,hj,g,Sa,PGA,Sa_1,Gamma,p,CF,disp,W1,weight)
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
%disp: Median displacement in x and y direction(from Linear analysis/vectors:from down to upper floors)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Output%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Calculation of Median responses and Dispersions for x and y direction

%Calculations%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

N=length(hj);%N: number of stories

S=Sa*weight./Vy;%Strength ratio

C1=zeros(1,2);
C2=zeros(1,2);
V=zeros(1,2);

for i=1:2
    %calculations for C1
    if S(i)<=1
        C1(i)=1;
    elseif T1(i)<=0.2
        C1(i)=1+(S(i)-1)/(0.04*a);
    elseif T1(i)<=1
        C1(i)=1+(S(i)-1)/(a*T1(i)^2);
    else
        C1(i)=1;
    end
    
    %calculations for C2
    if S(i)<=1
        C2(i)=1;
        S(i)=1;
    elseif T1(i)<=0.2
        C2(i)=1+((S(i)-1)^2)/32;
    elseif T1(i)<=0.7
        C2(i)=1+((S(i)-1)^2)/(800*T1(i)^2); nb
    else
        C2(i)=1;
    end
    
%Pseudo Lateral force-Base Shear
V(i)=C1(i)*C2(i)*Sa(i)*W1(i);
end

Td=eye(N);
Td(2:N+1:end)=-1;
hf=Td*hj;%height of each floor

drift_ratios(:,1)=disp(:,1)*V(1)./hf;
drift_ratios(:,2)=disp(:,2)*V(2)./hf;

PGV=(Sa_1*g/(2*pi))/1.65;

Hdr=zeros(N,2);
Hvel=zeros(N,2);
Hacc=zeros(N,2);
vs=zeros(N,2);
for i=1:2
    Hdr(:,i)=exp(CF(p,1)+CF(p,2)*T1(i)+CF(p,3)*S(i)+CF(p,4)*hj/hj(end)+CF(p,5)*(hj/hj(end)).^2+CF(p,6)*(hj/hj(end)).^3);
    Hvel(:,i)=exp(CF(p+3,1)+CF(p+3,2)*T1(i)+CF(p+3,3)*S(i)+CF(p+3,4)*hj/hj(end)+CF(p+3,5)*(hj/hj(end)).^2+CF(p+3,6)*(hj/hj(end)).^3);
    Hacc(:,i)=exp(CF(p+6,1)+CF(p+6,2)*T1(i)+CF(p+6,3)*S(i)+CF(p+6,4)*hj/hj(end)+CF(p+6,5)*(hj/hj(end)).^2+CF(p+6,6)*(hj/hj(end)).^3);
    vs(:,i)=PGV+0.3*T1(i)*(Vy*g*Gamma(i)/W1(i))*(disp(:,i)/disp(end,i))/(2*pi);
end

%median values of demands
m_drift_ratios=Hdr.*drift_ratios;%median drift ratios
m_vel_ratios=Hvel.*vs;%median velocity ratios
m_accel=Hacc.*PGA; %median acceleration

%dispersions of demands(FEMA P-58-1)
beta=importdata('Dispersions.mat');
b1=scatteredInterpolant(beta(:,1),beta(:,2),beta(:,3));
b2=scatteredInterpolant(beta(:,1),beta(:,2),beta(:,4));
b3=scatteredInterpolant(beta(:,1),beta(:,2),beta(:,5));
b4=scatteredInterpolant(beta(:,1),beta(:,2),beta(:,6));

b_SD=zeros(1,2);
b_FA=zeros(1,2);
b_FV=zeros(1,2);

for i=1:2
b_ad=b1(T1(i),S(i));
b_aa=b2(T1(i),S(i));
b_av=b3(T1(i),S(i));
b_m=b4(T1(i),S(i));

%Total dispersion for drift,floor velocity and acceleration
b_SD(i)=sqrt(b_ad^2+b_m^2);
b_FA(i)=sqrt(b_aa^2+b_m^2);
b_FV(i)=sqrt(b_av^2+b_m^2);
end

%Residual Drift
b_RD=0.8;
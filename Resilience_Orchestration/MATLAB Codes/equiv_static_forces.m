function Fj=equiv_static_forces(T1,Sa,Sw,W,Soil_Site_class,hj)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Input%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%T1: fundamental period of structure(in sec) in x and y direction respectively
%Sa(T1): in g is the 5% damped spectral acceleration at the fundamental period,in x and y direction respectively
%Sw: in kips, is the lumped seismic weight at each floor(1;2;3;...etc)
%W: in kips, total weight of structure
%Vy: in kips, estimated yield base shear from Nonlinear Static Analysis,in x and y direction respectively
%Soil_Site_class: A,B,C,D,E from ASCE/SEI 7-10 characterization
%Phi: vector of fundamental modeshapes,in x(first column) and y(second column) direction
%hj: elevation(in ft) of each floor

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Output%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Calculation of Equivalent Lateral Forces(matrix:first column x, second column y,rows:number of stories%%%%%%%%

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

N=length(hj);%N: number of stories
%S=Sa*W./Vy;%Strength ratio
S=[1,1];
C1=zeros(1,2);
C2=zeros(1,2);
W1=zeros(1,2);
V=zeros(1,2);
Fj=zeros(N,2);

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
        C2(i)=1+((S(i)-1)^2)/(800*T1(i)^2);
    else
        C2(i)=1;
    end
    
    %calculations for W1(first mode effective weight)
    %W1(i)=(sum(Sw.*Phi(:,i)))^2/(sum(Sw.*Phi(:,i).^2));
    W1(i)=W;
    if W1(i)<0.8*W
        W1(i)=0.8*W;
    end

    %Pseudo Lateral force-Base Shear
    V(i)=C1(i)*C2(i)*Sa(i)*W1(i);
    
    %Vertical Distribution of Lateral Forces
    if T1(i)<0.5
        k=1;
    elseif T1(i)>2.5
        k=2;
    else
        k=0.75+0.5*T1(i);
    end
   
    Fj(:,i)=V(i)*(Sw.*hj.^k)/sum(Sw.*hj.^k);
end
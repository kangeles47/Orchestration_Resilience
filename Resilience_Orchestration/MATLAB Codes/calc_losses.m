function CT=calc_losses(mean_drifts,b_SD,beta,theta,Nz,RC,Na,quant)

%This function calculates the mean total repair cost for each floor(in a
%specified direction-column vector).

%This function uses as the only EDP the drift ratios of each floor.

%Nz:number of samples generated(user defined).

%theta:median value of the probability distribution(row vector, for each
%damage state)

%beta:logarithmic standard deviation(row vector, for each
%damage state).

%mean_drifts:corrected drift ratios from The Equivalent static forces
%method(FEMA P-58).

%b_SD:dispersion for the drift ratios(FEMA P-58).

%RC:Average repair cost for lower quantity of repairs(row vector, for each
%damage state)

N=length(theta);%number of damage states.
L=zeros(length(mean_drifts),Nz);
Td=eye(N);
Td(2:N+1:end)=-1;
%Assembly-based vulnerability approach for estimation of direct seismic
%losses.

%Monte Carlo Simulation
for i=1:Nz
    z=randn;
    D=mean_drifts*exp(z*b_SD);
    for j=1:Na
        F=frag_curve(D,theta(j,:),beta(j,:));
        P=(Td'*F(:,1:end)')';
     
        L(:,i)=(RC(j,:)*P')'*quant(j)+L(:,i);
    end
end

L=sort(L,2);
CT=mean(L,2);
    
end

   
    





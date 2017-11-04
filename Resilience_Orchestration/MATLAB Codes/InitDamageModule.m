function [TotalCost]=InitDamageModule(mean_drift_ratios,mean_accel,B_SD,B_FA,B_FV,B_RD,num_int)
%% Comments
%This is the initialization script for the Damage Module. The above
%parameters will be fed in from Python (this is already set up so if you
%need to delete any of these, just make sure you delete it in this function
%as well as on the call to the function in MATLAB.

%mean_drift_ratios and mean_accel matrices are (length(hj),num_int*2) so in
%this case (2,16). Every two columns has drift ratios for 1st and 2nd floor
%for that specific intensity (floors are rows, x and y are columns)

%dispersion vectors are (1,num_int*2) so every two entries is the
%dispersion for x and y, respectively. 

%% Test Script 
Na=2;%number of damage assemblies

theta=[0.4 2.26 2.67;0.0175 0.0225 0.0322]';%median values of the two different fragility
%curves used(each row has the median values of the 3 damage
%stages[D1,D2,D3].First row:Exterior wall/Second row: OMF).

beta=[0.4 0.3 0.25;0.4 0.4 0.4]';%dispersion of the the two different fragility
%curves used.(each row has the dispersions of the 3 damage
%stages[D1,D2,D3].First row:Exterior wall/Second row: OMF).

RC=[1776.67 3720 5460;27846 38978.4 47978.4];%cost of the the two different fragility
%curves used.(each row has the average cost of the 3 damage
%stages[D1,D2,D3].First row:Exterior wall/Second row: OMF).

quant=[8,4];%quantity of each damage assembly

Nz=1000; %number of samples we are considering

for i=1:m
    Sa=[Sax(i),Say(i)];
    [m_drift_ratios(:,j:j+1),m_vel_ratios(:,j:j+1),m_accel(:,j:j+1),b_SD(i,:),b_FA(i,:),b_FV(i,:),b_RD]=median_dispersions(T1,Vy,hj,g,Sa,PGA(i),Sa_1(i),Gamma,p,CF,disp,W1,W);
    
    for k=1:2
    Cost(:,k+(j-1))=calc_losses(m_drift_ratios(:,k+(j-1)),b_SD(i,k),beta,theta,Nz,RC,Na,quant);
    end
    j=j+2;
end

%Cost is a matrix:first column is the x direction cost starting from the
%first floor and going upwards. Second column is the y direction.This
%average cost is for one intensity-scenario of spectral acceleration.


end
%Test script

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

quant=[8,8];%quantity of each damage assembly

for i=1:2
    Cost(:,i)=calc_losses(mean_drifts(:,i),b_SD,beta,theta,Nz,RC,Na,quant);
end

%Cost is a matrix:first column is the x direction cost starting from the
%first floor and going upwards. Second column is the y direction.This
%average cost is for one intensity-scenario of spectral acceleration.

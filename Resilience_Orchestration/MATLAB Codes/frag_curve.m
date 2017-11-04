function F=frag_curve(D,theta,beta)
%This function returns the values of a fragility function, given the demand
%parameter D, the median value theta and the logarithmic standard deviation
%beta.

%F is the conditional probability that the component will be damaged to
%state i(standard normal(Gaussian) cumulative distribution function).

%D:demand parameter(drifts, velocity etc.).
%theta:median value of the probability distribution.
%beta:logarithmic standard deviation.

F=zeros(length(D),length(theta));
for i=1:length(theta)
    F(:,i)=normcdf(log(D/theta(i))/beta(i));
end

end



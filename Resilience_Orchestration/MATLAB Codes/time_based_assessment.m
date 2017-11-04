function [lfm,Dl,Sax,Say,PGA,Sa_1]=time_based_assessment(T1x,T1y,num_int,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y)
%This function calculates all the values described in FEMA P58 for Time
%Based Assessments.

Tm=(T1x+T1y)/2;%mean of T1x and T1y

%Finding Sa_min
if Tm<=1
    Sa_min=0.05;
else
    Sa_min=0.05/Tm;
end

%Finding Sa_max[ Sa(Tm) evaluated at l_max]
l_max=0.0002;%maximum mean annual frequency of exceedance.

[Sa_max,~]=haz_curve_l(Tm,l_max,1,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,1);

%Finding Sa
Interval=(Sa_max-Sa_min)/num_int;%length of each interval

Sa=Sa_min:Interval:Sa_max;%Sa of endpoints of intervals

Sa_m=mean([Sa(1:end-1);Sa(2:end)]);%Finding Sa in the middle of each interval

%Finding the corresponding lfm(in the middle of each interval) an Dli
[~,lf]=haz_curve_l(Tm,1,Sa,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,0);
[~,lfm]=haz_curve_l(Tm,1,Sa_m,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,0);

Dl=lf(1:end-1)-lf(2:end);%mean annual probability of occurrence of ground motions
                         %within an interval Dli.  

%Finding for each lfm the Sax=Sa(T1x) and Say=Sa(T1y)
[Sax,~]=haz_curve_l(T1x,lfm,Sa_min,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,1);
[Say,~]=haz_curve_l(T1y,lfm,Sa_min,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,1);

%Finding for each lfm the PGA and Sa(1 sec)
PGA=interp1(PGAy,PGAx,lfm,'PCHIP');
Sa_1=interp1(SA1y,SA1x,lfm,'PCHIP');
end
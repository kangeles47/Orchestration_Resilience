function [Sa,lf]=haz_curve_l(Tm,l,S,PGAx,PGAy,SA1x,SA1y,SA02x,SA02y,flag)
%This function does all the interpolations-between values of the same 
%hazard curve and also interpolations between curves.

if flag==1
    lf=1;
    if Tm<0.2
       Sa_PGA=interp1(PGAy,PGAx,l,'PCHIP');
       Sa_02=interp1(SA02y,SA02x,l,'PCHIP');
       Sa=interp1([0;0.2],[Sa_PGA;Sa_02],Tm);
    elseif Tm>=0.2 && Tm<0.7
       Sa=interp1(SA02y,SA02x,l,'PCHIP');
    else
       Sa=interp1(SA1y,SA1x/Tm,l,'PCHIP');
    end
else
    Sa=1;
    if Tm<0.2
       l_PGA=interp1(PGAx,PGAy,S,'PCHIP');
       l_02=interp1(SA02x,SA02y,S,'PCHIP');
       lf=interp1([0;0.2],[l_PGA;l_02],Tm);
    elseif Tm>=0.2 && Tm<0.7
       lf=interp1(SA02x,SA02y,S,'PCHIP');
    else
       lf=interp1(SA1x/Tm,SA1y,S,'PCHIP');
    end
end

end

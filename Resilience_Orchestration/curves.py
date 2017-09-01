# -------------------------------------------------------------------------------
# Name:        curves.py
# Purpose:     Use USGS data to create and query hazard curves
#
# Author:      Holly Tina Ferguson hfergus2@nd.edu
#
# Created:     07/06/2017
# Copyright:   (c) Holly Tina Ferguson 2017
# Licence:     The University of Notre Dame
# Acknowledgement: S. Nagrecha 2017
# -------------------------------------------------------------------------------

# #!/usr/bin/python
import os
import numpy as np
import matplotlib.pyplot as plt
from scipy.interpolate import UnivariateSpline

def ImputeZeros(_x, _y):
    """Returns modified in-place versions _x & _y where the value of zero is slightly shifted by DELTA"""
    _x = list(_x) #because tuples are special creatures...
    _y = list(_y)

    # Do not worry about overflow errors: (RuntimeWarning: overflow encountered in power)...
    # Numbers will still compute and print...see output, this same example running is something like [-9.62392027] for that one model
    DELTA = 2**(-256)
    for i in range(len(_x)):
        if _x[i]==0:
            _x[i] += DELTA
        if _y[i]==0:
            _y[i] += DELTA
    return tuple(_x), tuple(_y) #re-cast the modified lists as tuples befoire returning

# import multipolyfit as mpf
def InferSpline(x,y,cityname,modelname,savefigures,degree=3,GRANULARITY=500):
    x_lin = np.linspace(min(x),max(x),GRANULARITY)

    # make sure you don't have any zeroes around, or else you'll get an -Inf.
    # I don't know what that does to splines, all I know is that it can't be good
    #print "X = ", x
    #print "Y = ", y
    #print "log(X) = ", np.log(x)
    #print "log(Y) = ", np.log(y)

    x_clean,y_clean = ImputeZeros(x,y)
    spl = UnivariateSpline(np.log(x_clean),np.log(y_clean),k=degree)
    y_lin = np.exp(spl(np.log(x_lin)))

    if savefigures:
        plt.plot(x, y, 'kx')
        plt.plot(x_lin, y_lin, 'b-')
        plt.title(cityname + "\n" + modelname)
        plt.xscale("log")
        plt.yscale("log")
        plt.savefig(os.path.join("figures",cityname + modelname + ".png"),dpi=500)
    return spl




class Curves():
    # Input parameters

    def querycurves(self,citydatanesteddict,savefigs):
        """
        Builds an interpolated spline for each model for each city
        citydatanesteddict: looks like this {city_name: {model: (X,Y) }}
        savefigs: Boolean. Saves figures into a common directory for now if 'True'

        returns: {city_name: {model: spline}}

        In a future version, something more advanced / modular than splines can be swapped out and vars can be renamed
        """
        model_splines = {}
        for _city in citydatanesteddict:
            model_splines[_city] = {}
            for _model in citydatanesteddict[_city]:
                hazardcurve_coarse = citydatanesteddict[_city][_model]
                hazard_x, hazard_y = zip(*hazardcurve_coarse)
                hazard_spl = InferSpline(hazard_x,hazard_y,cityname=_city, modelname=_model, savefigures=savefigs)
                model_splines[_city][_model] = hazard_spl
        return model_splines

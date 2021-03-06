#!/usr/bin/env python
#usage: formatData.py experiment_letter infilename outfilename

#This module includes helper routines for use in ISMIP-HOM verification.  In particular, 
#the contained routines are used to extract data for intercomparison

import sys
import pycdf

def extractMapView(ncdf, fields, fromSurface, time):
    #Get the staggered grid dimensions
    x0dim = ncdf.dim("x0")
    y0dim = ncdf.dim("y0")
    nx = x0dim.inq_len()
    ny = y0dim.inq_len()

    vars = [ncdf.var(f) for f in fields]


    rows = []

    #Account for periodic BCs by ignoring the ghost cells
    #We also account for the fact that we are on a staggered grid by offsetting
    #the outputted values
    for i in range(nx-1):
        for j in range(ny-1):
            xhat = float(i+.5)/float(nx - 1)
            yhat = float(j+.5)/float(ny - 1)

            row = [xhat, yhat]
            for var, s in zip(vars, fromSurface):
                #Get the level that we are extracting from
                if s:
                    level = 0
                else: #from base
                    level = ncdf.dim("level").inq_len() - 1

                row.append(var.get_1((time,level,j,i)))
                
            rows.append(row)

    return rows

def extractFlowline(ncdf, fields, fromSurface, time, transpose=False):
    #Get the staggered grid dimensions
    x0dim = ncdf.dim("x0")
    y0dim = ncdf.dim("y0")
    
    nx = x0dim.inq_len()
    ny = y0dim.inq_len()

    if transpose:
        nPoints = ny
        flowlineCenter = nx/2
    else:
        nPoints = nx
        flowlineCenter = ny/2

    vars = [ncdf.var(f) for f in fields]

    rows = []

    for i in range(nPoints-1):
        xhat = float(i+.5)/float(nPoints - 1)

        row = [xhat]
        for var,s in zip(vars,fromSurface):
            #Get the level that we are extracting from
            if s:
                level = 0
            else: #from base
                level = ncdf.dim("level").inq_len() - 1

            if transpose:
                row.append(var.get_1((time,level,i,flowlineCenter)))
            else:
                row.append(var.get_1((time,level,flowlineCenter,i)))
        rows.append(row)

    return rows

if __name__ == "__main__":
    from getopt import gnu_getopt
    optlist, args = gnu_getopt(sys.argv, '', ['tstep='])
    opts = dict(optlist)
    experimentLetter = args[1].lower()
    inFileName = args[2]
    outFileName = args[3]

    ncdf = pycdf.CDF(inFileName)

    if "--tstep" in opts:
        tstep = int(opts["--tstep"])
    else:
        tstep = 0

    if experimentLetter == "a":
        rows = extractMapView(ncdf, ["uvelhom","vvelhom","wvel","tau_xz","tau_yz"],
                                    [True,     True,     True,  False,   False], tstep)
    elif experimentLetter == "b":
        rows = extractFlowline(ncdf, ["uvelhom", "wvel", "tau_xz"],
                                     [True,      True,   False], tstep)
    elif experimentLetter == "c":
        rows = extractMapView(ncdf, ["uvelhom","vvelhom","wvel","uvelhom","vvelhom","tau_xz","tau_yz"],
                                    [True,     True,     True,  False,    False,    False,   False], tstep)
    elif experimentLetter == "d":
        rows = extractFlowline(ncdf, ["uvelhom", "wvel", "uvelhom", "tau_xz"],
                                     [True,      True,   False,     False], tstep)

    ncdf.close()

    #Output
    outfile = open(outFileName, "w")
    for line in rows:
        print >>outfile, "\t".join([str(i) for i in line])
    outfile.close()

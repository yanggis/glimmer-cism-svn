#! /usr/bin/env python

# Copyright 2004, Magnus Hagdorn
# 
# This file is part of GLIMMER.
# 
# GLIMMER is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# GLIMMER is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with GLIMMER; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

"""plot statistics of an ice sheet."""

import PyGMT,PyCF,sys, numpy

# creating option parser
parser = PyCF.CFOptParser()
parser.width=15.
parser.profile(vars=False)
parser.add_option("-e","--eismint",default=False,action="store_true",help="plot central thickness")
parser.add_option("-f","--file",metavar='NAME',type="string",dest='dataname',help="name of file containing ice extent data")
parser.add_option("-m","--meltfrac",default=False,action="store_true",help="extract fractional melt area.")
parser.add_option("-i","--icethickness",default=False,action="store_true",help="plot average ice thickness")
parser.plot()
opts = PyCF.CFOptions(parser,-2)

do_extent = opts.options.profname != None
eismint = opts.options.eismint

plot = opts.plot()
plot.defaults['LABEL_FONT_SIZE']='12p'
plot.defaults['ANNOT_FONT_SIZE']='10p'
bigarea = PyGMT.AreaXY(plot,size=opts.papersize)
tsarea = PyCF.CFAreaTS(bigarea,pos=[0.,4.5],size=[opts.options.width,opts.options.width/4])
key = PyGMT.KeyArea(bigarea,size=[opts.options.width,3.])

if opts.options.meltfrac:
    mf = tsarea.newts()
    mf.xlabel = 'time [ka]'
    mf.ylabel = 'melt fraction'
else:
    mf = None
iv = tsarea.newts()
iv.xlabel = 'time [ka]'
iv.ylabel = 'ice volume'
ia = tsarea.newts()
ia.xlabel = 'time [ka]'
ia.ylabel = 'ice area'
if do_extent:
    ie = tsarea.newts()
    ie.xlabel = 'time [ka]'
    ie.ylabel = 'ice extent'
if eismint:
    eis = tsarea.newts()
    eis.xlabel = 'time [ka]'
    eis.ylabel = 'divide and midpoint ice thickness [m]'
if opts.options.icethickness:
    ithick = tsarea.newts()
    ithick.xlabel = 'time [ka]'
    ithick.ylabel = 'average ice thickness [m]'
else:
    ithick = None
    
for fnum in range(0,len(opts.args)-1):
    if do_extent:
        cffile = opts.cfprofile(fnum)
    else:
        cffile = opts.cffile(fnum)

    times = cffile.time(None)

    key.plot_line(cffile.title,'1/%s'%PyCF.CFcolours[fnum])

    ice_area = cffile.getIceArea()
    ice_vol = cffile.getIceVolume()

    iv.line('-W1/%s'%PyCF.CFcolours[fnum],times,ice_vol)
    ia.line('-W1/%s'%PyCF.CFcolours[fnum],times,ice_area)

    if do_extent:
        interval = int(PyGMT.round_down(len(times)/100.))
        if interval == 0:
            interval = 1
        
        ice_extent = cffile.getExtent(interval=interval)
        ie.line('-W1/%s'%PyCF.CFcolours[fnum],times[::interval],ice_extent)

    if mf != None:
        melt_data = cffile.getFracMelt()
        mf.line('-W1/%s'%PyCF.CFcolours[fnum],times,melt_data)

    if ithick != None:
        mthick =[]
        for i in range(0,len(ice_area)):
            if ice_area[i]>0:
                mthick.append(ice_vol[i]/ice_area[i])
            else:
                mthick.append(0.)
        ithick.line('-W1/%s'%PyCF.CFcolours[fnum],times,mthick)

    if eismint:
        thk = cffile.getvar('thk')
        divide   = [len(cffile.file.variables['x1'][:])/2,len(cffile.file.variables['y1'][:])/2]
        midpoint = [3*len(cffile.file.variables['x1'][:])/4,len(cffile.file.variables['y1'][:])/2]
        eis.line('-W1/%s'%PyCF.CFcolours[fnum],times,thk.getSpotIJ(divide,time=None))
        eis.line('-W1/%s'%PyCF.CFcolours[fnum],times,thk.getSpotIJ(midpoint,time=None))

    cffile.close()

if do_extent and opts.options.dataname != None:
    efile = open(opts.options.dataname)
    etime = []
    edata = []
    for l in efile.readlines():
        l = l.split()
        etime.append(float(l[0])*cffile.timescale)
        edata.append(float(l[1])*cffile.xscale)
    ie.line('-W1/0/0/0',etime,edata)
    key.plot_line('reconstruction','1/0/0/0')

tsarea.finalise(expandy=True)
tsarea.coordsystem()

plot.close()

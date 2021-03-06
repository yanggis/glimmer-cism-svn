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

"""A simple plot of CF fields."""

import PyGMT,PyCF,sys,string, Numeric

def contour(area,data,contours,time):
    """Contour data.

    area: CF area
    data: CF field to be contoured
    contours: contour string.
    time: time slice"""

    if contours!=None:
        cntrs=contours.split('/')
        if len(cntrs)==3:
            c = Numeric.arange(float(cntrs[0]), float(cntrs[1]), float(cntrs[2])).tolist()
            area.contour(data,c,'-W2/0/0/0',time)
        elif len(cntrs)==4:
            c = Numeric.arange(float(cntrs[0]), float(cntrs[1]), float(cntrs[2])).tolist()
            area.contour(data,c,'-W2/0/0/0to',time)
            c = Numeric.arange(float(cntrs[0]), float(cntrs[1]), float(cntrs[3])).tolist()
            area.contour(data,c,'-W2/0/0/0 -At',time,cntrtype='a')
        else:
            print 'Warning, cannot parse contour settings, %s.'%contours
            return
        
# creating option parser
parser = PyCF.CFOptParser()
parser.variable()
parser.add_option("--contours",metavar='CONT',help="Set contour start, end value and interval with CONT=start/end/interval[/annotated interval]")
parser.add_option("-g","--glyph",metavar='VAR',type="choice",dest='glyph',choices=['vel','vel_avg','bvel','bvel_tavg'],help="Add velocity glyphs to plot, VAR can be one of [vel,vel_avg,bvel,bvel_tavg]")
parser.add_option("--shapefile",metavar='FNAME',help="plot a shape file, e.g. LGM extent....")
parser.profile_file(plist=True)
parser.time()
parser.region()
parser.plot()
opts = PyCF.CFOptions(parser,-2)

if opts.options.level == None:
    level = 0
else:
    level = opts.options.level

count = 0
numplots = 0
if opts.nvars>1:
    count = count + 1
    numplots = opts.nvars
if opts.ntimes>1:
    count = count + 1
    numplots = opts.ntimes
if opts.nfiles>1:
    count = count + 1
    numplots = opts.nfiles
    
if count > 1:
    sys.stderr.write('Error, can only have either more than one time slice or more than one variable or more than one file!\n')
    sys.exit(1)

infile = opts.cffile()
var  = opts.vars(infile)
time = opts.times(infile)
# get number of plots
deltax = 1.
deltay = 1.
sizex = opts.options.width+deltax
sizey = infile.aspect_ratio*opts.options.width+deltay

plot=None
if numplots > 1:
    numx = int((opts.papersize[0])/(sizex))
    numy = int((opts.papersize[1])/(sizey))
    numpages = int(float(numplots-0.1)/float(numx*numy))
    p=-1
    for i in range(0,numplots):
        if i%(numx*numy)==0:
            # need to open a new plot file
            if plot!=None:
                plot.close()
            if numpages>0:
                p=p+1
                plot = opts.plot(number=p)
            else:
                p=0
                plot = opts.plot()
            bigarea = PyGMT.AreaXY(plot,size=opts.papersize)

        if opts.nfiles>1:
            infile = opts.cffile(i)
        if opts.nvars>1:
            var  = opts.vars(infile,i)
        else:
            var  = opts.vars(infile)
        if opts.ntimes>1:
            time = opts.times(infile,i)
        else:
            time = opts.times(infile)
        x = i%numx
        y = int((i-p*(numx*numy))/numx)
        area = PyCF.CFArea(bigarea,infile,pos=[x*sizex,opts.papersize[1]-(y+1)*sizey],size=sizex-deltax)
        if opts.options.land:
            area.land(time,illuminate=opts.options.illuminate)
        area.image(var,time,clip = opts.options.clip,level=level,mono=opts.options.mono,illuminate=opts.options.illuminate)
        if opts.options.glyph!=None or var.name in ["vel","bvel","vel_avg","bvel_tavg"]: 
            area.velocity_field(time,level=level)
        area.coastline()
        try:
            thk = infile.getvar('thk')
            area.contour(thk,[0.1],'-W2/0/0/0',time)
        except:
            pass
        if opts.options.shapefile != None:
            area.shapefile(opts.options.shapefile)
        if opts.options.profname !=None:
            i=0
            for pn in opts.options.profname:
                pdata = PyCF.CFprofile(infile,interval=opts.options.interval)
                pdata.coords_file(pn,opts.options.prof_is_projected)
                area.profile(args='-W5/0/0/0',prof=pdata,slabel=string.ascii_uppercase[i])
                i=i+1
        contour(area,var,opts.options.contours,time)
        area.axis='wesn'
        area.coordsystem()
        area.printinfo(time)
else:
    plot = opts.plot()
    area = PyCF.CFArea(plot,infile,pos=[0.,3.],size=sizex-deltax)
    if opts.options.land:
        area.land(time,illuminate=opts.options.illuminate)
    area.image(var,time,clip = opts.options.clip,level=level,mono=opts.options.mono,illuminate=opts.options.illuminate)
    if opts.options.glyph!=None or var.name in ["vel","bvel","vel_avg","bvel_tavg"]: 
        area.velocity_field(time,level=level)
    
    area.coastline()
    try:
        thk = infile.getvar('thk')
        area.contour(thk,[0.1],'-W2/0/0/0',time)
    except:
        pass
    if (var.name == 'is' or var.name == 'thk') and opts.options.contours == None:
        area.contour(var,[500,1000,2500,3000],'-W1/255/255/255',time)
    if opts.options.profname !=None:
        i=0
        for pn in opts.options.profname:
            pdata = PyCF.CFprofile(infile,interval=opts.options.interval)
            pdata.coords_file(pn,opts.options.prof_is_projected)
            area.profile(args='-W5/0/0/0',prof=pdata,slabel=string.ascii_uppercase[i])
            i=i+1
    if opts.options.shapefile != None:
        area.shapefile(opts.options.shapefile)
    contour(area,var,opts.options.contours,time)
    area.coordsystem()
    area.printinfo(time)
if opts.options.dolegend:
    PyGMT.colourkey(area,var.colourmap.cptfile,title=var.long_name,args='-L',pos=[0,-2])
    
plot.close()

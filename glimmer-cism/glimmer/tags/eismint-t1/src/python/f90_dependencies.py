#! /usr/bin/env python

# Copyright 2004, Magnus Hagdorn
# 
# This file is part of glimmer.
# 
# PyGMT is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# PyGMT is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with PyGMT; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# python script for analysing module dependencies of a number of f90/f95 programs

import string, getopt, sys, os, os.path

external_mod = ['f95_lapack','netcdf','blas_dense']

def search_file(name):
    "function searching a f90/95 file if it contains module information and/or uses modules and/or includes files"

    n = os.path.basename(name)
    result = {}
    result['name'] = string.replace(n,'.','_')
    result['realname'] = n
    result['modname'] = ''
    result['includes'] = []
    result['uses'] = []
    result['prog'] = 0
    result['process'] = 1

    # open file
    file = open(name,'r')

    # parsing file
    for l in file.readlines():
        l = string.lower(l)
        # searching for comments and stripping them
        pos = string.find(l,'!')
        if pos is not -1:
            l = l[:pos]
        # finding use statement
        pos = string.find(l,'use')
        if pos is not -1:
            pos = pos+len('use')
            pos2 = string.find(l,',')
            if pos2==-1:
                module = string.strip(l[pos:])
            else:
                module = string.strip(l[pos:pos2])
            if module not in result['uses'] and module not in external_mod:
                result['uses'].append(module)
            continue
        # finding include statements
        pos = string.find(l,'include')
        if pos is not -1:
            pos = pos+len('include')
            include = string.strip(l[pos:])
            if string.find(include,'<') is not -1:
                continue
            include = string.replace(include,'\"','')
            include = string.replace(include,'\'','')
            if include  not in result['includes']:
                result['includes'].append(include)
            continue
        # finding module statement
        pos = string.find(l,'module')
        if pos is not -1:
            pos = pos + len('module')
            result['modname'] = string.strip(l[pos:])
            continue
        if string.find(l,'end program') is not -1:
            result['prog'] = 1
        
    file.close()
    return result

def reduce(names,files,modules):
    "reduce list to be processed to names + dependencies"

    for r in files:
        r['process']=0

    for n in names:
        recurse_mark(n,files,modules)

def recurse_mark(name,files,modules):
    "recursively mark used ones"

    for r in files:
        if name == r['realname']:
            r['process'] = 1
            for mod in r['uses']:
                if mod in modules.keys():
                    recurse_mark(modules[mod],files,modules)
            break            

def print_dot(out,files,modules,onlymod=0):
    "print dot file to out"

    out.write( 'digraph G {\n')
    out.write( '\toverlap=false\n')
    out.write( '\tspline=true\n')
    for r in files:
        flags = '[label="%s"'%r['realname']
        if len(r['modname']) > 0:
            flags = flags + ',shape=box'
        if r['prog'] is 1:
            flags = flags + ',color=red'
        flags = flags + ']'
        if (onlymod is 1 and len(r['modname']) > 0) or onlymod is 0:
            if r['process'] is 1:
                out.write( '\t%s %s;\n'%(r['name'],flags))
    for r in files:
        if (onlymod is 1 and len(r['modname']) > 0) or onlymod is 0:
            if r['process'] is 1:
                for mod in r['uses']:
                    if mod in modules.keys():
                        out.write( '\t%s -> %s ;\n'%(r['name'],modules[mod]))
    out.write( '}\n'    )

def print_makefile(out,files,modules):
    "print Makefile dependencies"

    for r in files:
        out.write("%s.o:\t\t"%os.path.splitext(r['realname'])[0])
        for mod in r['uses']:
            if mod in modules.keys():
                if modules[mod] != r['realname']:
                    out.write("%s.o "%os.path.splitext(modules[mod])[0])
        for inc in r['includes']:
            out.write("%s "%inc)
        out.write("%s\n"%r['realname'])

def usage():
    "short help message"
    print 'Usage: f90_dependencies [OPTIONS] f90files'
    print 'extract module dependencies from set of f90/95 files'
    print ''
    print '  -h, --help\n\tthis message'
    print '  -d, --dot\n\tchange output format to dot (default is Makefile dependencies)'
    print '  -p file, --process=file\n\tonly processes dependencies for file (more than one can be specified)'
    print '  -m, --mod\n\tonly process modules (only honour when producing dot)'
    print '  -o file, --output=file\n\twrite to file (default: stdout'

if __name__ == '__main__':

    try:
        opts, args = getopt.getopt(sys.argv[1:],'hdmo:p:',['help','dot','mod','output=','process='])
    except getopt.GetoptError:
        # print usage and exit
        usage()
        sys.exit(2)
   
    if len(args) < 2:
        # print usage and exit
        usage()
        sys.exit(2)

    dot = 0
    mod = 0
    outfile = sys.stdout
    process = []
    for o,a in opts:
        if o in ('-h', '--help'):
            usage()
            sys.exit(0)
        if o in ('-d','--dot'):
            dot = 1
        if o in ('-m', '--mod'):
            mod = 1
        if o in ('-p', '--process'):
            process.append(a)
        if o in ('-o', '--output'):
            outfile = open(a,'w')

    f90files = []
    modnames = {}
    modrnames = {}
    for arg in args:
        r = search_file(arg)
        f90files.append(r)
        if len(r['modname']) > 0:
            if r['modname'] not in modnames.keys():
                modnames[r['modname']] = r['name']
                modrnames[r['modname']] = r['realname']

    if dot is 1:
        if len(process)>0:
            reduce(process,f90files,modrnames)
            mod = 0
        print_dot(outfile,f90files,modnames,mod)
    else:
        print_makefile(outfile,f90files,modrnames)

    outfile.close()

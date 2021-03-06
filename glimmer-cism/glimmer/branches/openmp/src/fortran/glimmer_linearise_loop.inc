! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! +                                                             +
! +  glimmer_linearise_loop.inc - part of the GLIMMER ice model + 
! +                                                             +
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
! 
! Copyright (C) 2004 GLIMMER contributors - see COPYRIGHT file 
! for list of contributors.
!
! This program is free software; you can redistribute it and/or 
! modify it under the terms of the GNU General Public License as 
! published by the Free Software Foundation; either version 2 of 
! the License, or (at your option) any later version.
!
! This program is distributed in the hope that it will be useful, 
! but WITHOUT ANY WARRANTY; without even the implied warranty of 
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License 
! along with this program; if not, write to the Free Software 
! Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 
! 02111-1307 USA
!
! GLIMMER is maintained by:
!
! Ian Rutt
! School of Geographical Sciences
! University of Bristol
! University Road
! Bristol
! BS8 1SS
! UK
!
! email: <i.c.rutt@bristol.ac.uk> or <ian.rutt@physics.org>
!
! GLIMMER is hosted on NeSCForge:
!
! http://forge.nesc.ac.uk/projects/glimmer/
!
! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 
#define LINEARISE_NSEW_LOOP(nsewc,nsc,nsstart,nsend,ewc,ewstart,ewend) \
     do nsewc=0,(nsend-nsstart+1)*(ewend-ewstart+1)-1; \
        nsc=nsstart+nsewc/(ewend-ewstart+1); \
        ewc=ewstart+mod(nsewc,ewend-ewstart+1)

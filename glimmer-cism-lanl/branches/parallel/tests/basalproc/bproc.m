
%% file to create .mat input variables for Marion's coupled runs
%%
%% To be read by .py script to make .nc input file

double_res = 0;     %% flag to double res of grid
% double_res = 1;

rho_i = 910;     % ice density kg/m^3
rho_w = 1028;    % ocean water density kg/m^3

H0 = 1e3;
T0 = -10;
q0 = -7e-2;
slope = 1e-6;
b0 = 0.25;

r = 22; c = 45;
dew = 5e3; dns = 5e3;
x = [0:dew:dew*c-1]; xs = ( x(1:end-1)+x(2:end) )/2;
y = [0:dns:dns*r-1]'; ys = ( y(1:end-1)+y(2:end) )/2;


if( double_res == 1 )
    dew = 1/2*dew; dns = 1/2*dns;    % make these active to double resolution
    r = 2*r; c = 2*c;
    x2 = [0:dew:dew*c-1]; x2s = ( x2(1:end-1)+x2(2:end) )/2;
    y2 = [0:dns:dns*r-1]'; y2s = ( y2(1:end-1)+y2(2:end) )/2;
end

l = 11;     % no of vert levels

thck = H0 * ones( r, c );
artm = T0 * ones( r, c );
bheatflx = q0 * ones( r, c );
acab = b0 * ones( r, c );

topg = repmat( linspace( -0.1e2, -0.1e2-(slope*(c-1)*dew), c), r, 1 );      %% for debugging

usrf = topg + thck;

%% put buffer of zero thickness cells around perimeter (for remapping)
thck(1:2,:) = 0; thck(:,1:2) = 0; thck(end-1:end,:) = 0; thck(:,end-3:end) = 0;
usrf(1:2,:) = 0; usrf(:,1:2) = 0; usrf(end-1:end,:) = 0; usrf(:,end-3:end) = 0;

figure(1), imagesc( x/1e3, y/1e3, thck ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'thickness (m)' )

figure(2), imagesc( x/1e3, y/1e3, topg ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'basal topg (m)' )

figure(3), imagesc( x/1e3, y/1e3, usrf ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'upper surface (m)' )

%% load in old till map
  load ~/Home/Code/GLAM/GLIMGLAM/SENS/new_UPB/trunk/GLAM/Tillggl           % Marion's path
%load ~/work/modeling/glam/glam-stream-marion-new/trunk/GLAM/Tillggl      % Steve's path

minTauf = Tillggl;

% %% hacks of minTauf field to make it easier for the model to converge
% ind = find( minTauf > 5e3 & minTauf <= 27500 ); minTauf(ind) = 7.5e3;
% ind = find( minTauf > 27500 ); minTauf(ind) = 1e4;
ind = find( minTauf < 2.5e3 ); minTauf(ind) = 1e3;

% minTauf = 10e3 * ones( r-1, c-1 );       % for debugging
% minTauf = 1e7 * ones( r-1, c-1 );       
% minTauf(5:end-4,:) = 5e3;
% if( double_res == 1 )
%     minTauf(10:end-9,:) = 5e3;
% end 

if( double_res == 1 )
    minTauf = interp2( xs, ys, minTauf, x2s, y2s, 'nearest' );
    ind = find( isnan( minTauf ) ); minTauf(ind) = max( max( minTauf ) );
end 

beta = 1e6*ones(size(minTauf));
ind = find( minTauf <= 5e3 ); beta(ind) = 1e2;
% beta(8:14,:) = 3e1;
% beta(10:12,:) = 0.5e1;0

figure(4), imagesc( x/1e3, y/1e3, minTauf/1e3 ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'Tau0 (kPa)' )

figure(5), imagesc( x/1e3, y/1e3, artm ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'artm temp (C)' )

figure(6), imagesc( x/1e3, y/1e3, bheatflx ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'geo flux (W m^2)' )

% %% add a kinbcmask field to specify where 0 flux bcs are
kinbcmask = zeros(size(minTauf));
kinbcmask(1:3,:) = 1; kinbcmask(end-2:end,:) = 1; kinbcmask(:,1:3) = 1;

uvelhom = zeros( l, r-1, c-1 );
for i=1:l
    uvelhom(i,:,:) = zeros(size(minTauf));
end

vvelhom = uvelhom; 

% bwat = 100*ones( size( topg ) );

figure(7), imagesc( x/1e3, y/1e3, kinbcmask ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'kinbcmask' )

figure(8), imagesc( x/1e3, y/1e3, acab ), axis xy, axis equal, axis tight, colorbar
xlabel( 'x (km)' ), ylabel( 'y (km)' ), title( 'acab (m/a)' )

tauf = minTauf;

  cd ~/Home/Code/GlimSLAB/parallel/tests/basalproc     % Marion's path
%cd /Users/sprice/work/modeling/cism/cism-parallel/tests/basalproc            % Steve's path

save bproc.mat artm acab bheatflx usrf topg thck beta tauf kinbcmask uvelhom vvelhom

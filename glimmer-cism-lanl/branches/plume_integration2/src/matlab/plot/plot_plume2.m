function [] = plot_plume2(dplume,dice,timeslice,flabel)

fig_dir = '/home/cvg222/matlab_figs/';

figure(1);
fs = 18;
fs3 = 14;
fs2 = 14;

solo_fig_x_size = 800;
solo_fig_y_size = 800;
three_panel_fig_x_size = 1250;
three_panel_fig_y_size = 500;
four_panel_fig_x_size = 1200;
four_panel_fig_y_size = 800;


thermal_forcing = @(depth,salt,temp) temp-(-5.73e-2*salt-7.61d-4*depth+8.32d-2);

if (timeslice < 0) 
    timeslice = size(dplume.su, 3);
end 

x = dice.xgrid;
y = dice.ygrid;

ice_u = squeeze(dice.uvelmean(:,:,timeslice));
ice_v = squeeze(dice.vvelmean(:,:,timeslice));

su = squeeze(dplume.su(:,:,timeslice));
sv = squeeze(dplume.sv(:,:,timeslice));
u = squeeze(dplume.u(:,:,timeslice));
v = squeeze(dplume.v(:,:,timeslice));
train = squeeze(dplume.train(:,:,timeslice));
bmelt = squeeze(dplume.bmelt(:,:,timeslice));
temp = squeeze(dplume.temp(:,:,timeslice));
salt = squeeze(dplume.salt(:,:,timeslice));
draft = squeeze(dplume.draft(:,:,timeslice));
thk_t = squeeze(dice.thk_t(:,:,timeslice));
T_forcing = thermal_forcing(abs(draft),salt,temp);
grad = squeeze(dplume.grad(:,:,timeslice));

j_start = 3;
j_stop = 118;

ice_def = - dice.flux_div(:,j_start:j_stop,timeslice) + ...
            dice.y_adv(:,j_start:j_stop,timeslice);
y_adv = - dice.y_adv(:,j_start:j_stop,timeslice);
ice_adv = -dice.flux_div(:,j_start:j_stop,timeslice) + ...
           dice.vel_div(:,j_start:j_stop,timeslice);   

[m,n] = size(draft);
channel_amp = zeros(m,n);
mean_draft = zeros(m,n);
max_draft = zeros(m,n);

for i=1:n
  channel_amp(:,i) = draft(:,i) - min(draft(:,i));
  mean_draft(:,i) = sum(draft(:,i))/m;
  max_draft(:,i) = min(draft(:,i));
end

stride = 2;
stride2 = 4;

scale = 2.0;
lw = 0.5;

fig1 = figure(1);
clf;

if (false)
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size])
hold on
contourf(x/1000.0,y/1000.0,grad',40,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
quiver(x(1:stride:end)/1000,y(1:stride:end)/1000,...
      su(1:stride:end,1:stride:end)',...
      sv(1:stride:end,1:stride:end)',...
     scale,'w','LineWidth',lw);
colormap jet;
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
title('Ocean Velocities with contourfs of ice draft gradient','FontSize',fs);
hold off
fname = strcat([fig_dir,'/plume_',flabel,'_grad']);
print('-depsc',fname);
end 

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size])

hold on
contourf(x/1000.0,y/1000.0,-draft',40,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
%caxis([000 650])
quiver(x(1:stride:end)/1000,y(1:stride:end)/1000,...
      su(1:stride:end,1:stride:end)',...
      sv(1:stride:end,1:stride:end)',...
      scale,'k','LineWidth',lw);
colormap jet;
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
caxis([0 600]);
title('Contours of Ice Draft (m) with plume velocities','FontSize',fs);
hold off
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_draft_vel']));
end

if (false)
figure(1);
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size])
clf;
hold on
contourf(x/1000.0,y/1000.0,-draft',40,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
%caxis([000 650])
%quiver(x(1:stride:end)/1000,y(1:stride:end)/1000,...
%      su(1:stride:end,1:stride:end)',...
%      sv(1:stride:end,1:stride:end)',...
%      scale,'k','LineWidth',lw);
colormap jet;
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
%caxis([0 800]);
title('Contours of Ice Draft (m)','FontSize',fs);
hold off
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_draft']));
end

if (false)
figure(1);
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size])
clf;
%subplot(1,2,2);
speed = sqrt(su.*su + sv.*sv);
hold on
contourf(x/1000.0,y/1000.0,bmelt',20,'EdgeColor','None') ;colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
%contour(x/1000.0,y/1000.0,draft',30,'w');
%caxis([min(min(bmelt)), max(max(bmelt))]);
%caxis([0 40]);
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
title('Basal Melt Rate (m/year)','FontSize',fs);
hold off
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_meltrate']));
end

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size])
hold on
%subplot(2,2,3)
contourf(x/1000.0,y/1000.0,train'/1000.0,...
         30,'EdgeColor','None') ;colorbar('FontSize',fs);
contour(x/1000.0,y/1000.0,train'/1000.0,[0 0],'k')
set(gca,'FontSize',fs2);
%contour(x/1000.0,y/1000.0,draft',20,'w');
%contour(x/1000.0,y/1000.0,draft',30,'w');
caxis([min(min(train/1000.0)), max(max(train/1000.0))]);
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
title('Entrainment/Detrainment Rate (1000m/year)','FontSize',fs);
hold off
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_train']));
end

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size])
%subplot(2,2,3);
hold on
contourf(x/1000.0,y/1000.0,temp',...
         30,'EdgeColor','None') ;colorbar('FontSize',fs);
%contour(dplume.x/1000.0,dplume.y/1000.0,dplume.draft',20,'w');
%contour(dplume.x/1000.0,dplume.y/1000.0,dplume.draft',30,'w');
caxis([min(min(temp)), max(max(temp))]);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
title('Plume Temperature (C)','FontSize',fs);
hold off
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_temp']));
end

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size])
hold on
contourf(x/1000.0,y/1000.0,T_forcing',...
         30,'EdgeColor','None') ;colorbar('FontSize',fs);
caxis([min(min(T_forcing)), max(max(T_forcing))]);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
title('Thermal Forcing (C)','FontSize',fs);
hold off
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_T_forcing']));
end

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
hold on
contourf(x/1000.0,y/1000.0,channel_amp',20,'EdgeColor','None') ;colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
caxis([min(min(channel_amp)) max(max(channel_amp))]);
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
title('Channel depth (m)','FontSize',fs);
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_channels']));
end

if (true)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
hold on;
[m,n,k] = size(dice.thk);
contourf(dice.Xgrid(:,j_start:n)/1000.0, ...
         dice.Ygrid(:,j_start:n)/1000.0, ...
         min(5.0,-dice.vel_div(:,j_start:n,timeslice)), ...
         30,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs)
ylabel('Along shelf distance (km)','FontSize',fs);
colorbar('FontSize',fs);
title('Thickness tendency due to ice divergence','FontSize',fs);    
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_ice_div']));
hold off
end

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
hold on;

contourf(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
         dice.Ygrid(:,j_start:j_stop)/1000.0, ...
         -dice.flux_div(:,j_start:j_stop,timeslice), ...
         25,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs)
ylabel('Along shelf distance (km)','FontSize',fs);
title('Thickness time tendency due to flux divergence','FontSize',fs);    
contour(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
        dice.Ygrid(:,j_start:j_stop)/1000.0, ...
        dice.thk(:,j_start:j_stop,timeslice), ...
        20,'w');
caxis([min(min(-dice.flux_div(:,j_start:j_stop,timeslice))) ...
       max(max(-dice.flux_div(:,j_start:j_stop,timeslice)))]);
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_flux_div']));
hold off
end

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
hold on;
contourf(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
         dice.Ygrid(:,j_start:j_stop)/1000.0, ...
         ice_adv, ...
         25,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs)
ylabel('Along shelf distance (km)','FontSize',fs);
title('Thickness time tendency due to ice advection term u\cdot \nabla H','FontSize',fs);    
%contour(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
%        dice.Ygrid(:,j_start:j_stop)/1000.0, ...
%        dice.thk(:,j_start:j_stop,timeslice), ...
%        20,'w');
caxis([0 80]);
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_ice_adv']));
hold off
end

if (false)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
hold on;
contourf(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
         dice.Ygrid(:,j_start:j_stop)/1000.0, ...
         y_adv, ...
         25,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs)
ylabel('Along shelf distance (km)','FontSize',fs);
title('Thickness time tendency due to ice advection term v_0*H_y','FontSize',fs);    
%contour(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
%        dice.Ygrid(:,j_start:j_stop)/1000.0, ...
%        dice.thk(:,j_start:j_stop,timeslice), ...
%        20,'w');
caxis([0 80]);
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_y_adv']));
hold off
end

if(false)
figure(1)
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
hold on;
   
contourf(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
         dice.Ygrid(:,j_start:j_stop)/1000.0, ...
         ice_def, ...
         25,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs)
ylabel('Along shelf distance (km)','FontSize',fs);
title('Ice deformation influence on H (m/year)','FontSize',fs);    
%contour(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
%        dice.Ygrid(:,j_start:j_stop)/1000.0, ...
%        dice.thk(:,j_start:j_stop,timeslice), ...
%        20,'w');
%caxis([0 40]);
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_ice_def']));
hold off
end

if (false)
figure(1);
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
clf;
hold on;
contourf(dice.Xgrid(:,:)/1000.0, ...
         dice.Ygrid(:,:)/1000.0, ...
         dice.thk_t(:,:,timeslice), ...
         25,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs)
ylabel('Along shelf distance (km)','FontSize',fs);
title('H_t/H','FontSize',fs);    
%caxis([-0.1 0.1]);
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_thk_t']));
hold off
end

if (true)
figure(1);
clf;
set(fig1,'Position',[1 1 three_panel_fig_x_size three_panel_fig_y_size]);
subplot(1,3,3);
hold on
contourf(x/1000.0,y/1000.0,channel_amp',40,'EdgeColor','None');colorbar('FontSize',fs3);
set(gca,'FontSize',fs3);
colormap jet;
%[C,h] = contour(x/1000.0,y/1000.0,max_draft',10,'w');
caxis([min(min(channel_amp)) max(max(channel_amp))]);
xlabel('Across shelf distance (km)','FontSize',fs3);

%clabel(C,'manual','FontSize',fs3,'Color','w')
%title('Channel depth (m) with deepest-draft contours','FontSize',fs3);
title('Channel depth (m)','FontSize',fs3);
hold off

subplot(1,3,2);
hold on
contourf(x/1000.0,y/1000.0,bmelt',20,'EdgeColor','None') ;colorbar('FontSize',fs3);
set(gca,'FontSize',fs3);
xlabel('Across shelf distance (km)','FontSize',fs3);
title('Basal Melt Rate (m/year)','FontSize',fs3);
hold off

subplot(1,3,1);
hold on
contourf(x/1000.0,y/1000.0,-draft',40,'EdgeColor','None') ;colorbar('FontSize',fs3);
set(gca,'FontSize',fs3);
xlabel('Across shelf distance (km)','FontSize',fs3);
ylabel('Along shelf distance (km)','FontSize',fs3);
title('Ice draft (m)','FontSize',fs3);
hold off

fname = strcat([fig_dir,'/plume_',flabel,'_3panel']);
print('-depsc',fname);
end


if (true)
figure(1);
clf;
set(fig1,'Position',[1 1 four_panel_fig_x_size four_panel_fig_y_size]);
subplot(2,2,1);
hold on
contourf(x/1000.0,y/1000.0,bmelt',40,'EdgeColor','None');colorbar('FontSize',fs3);
set(gca,'FontSize',fs3);
colormap jet;
xlabel('Across shelf distance (km)','FontSize',fs3);
ylabel('Along shelf distance (km)','FontSize',fs3);
title('Basal melt rate (m/year)','FontSize',fs3);
hold off

subplot(2,2,2);
hold on
contourf(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
         dice.Ygrid(:,j_start:j_stop)/1000.0, ...
         ice_def,40,'EdgeColor','None') ;colorbar('FontSize',fs3);
set(gca,'FontSize',fs3);
xlabel('Across shelf distance (km)','FontSize',fs3);
title('Influence of ice deformation (m/year)','FontSize',fs3);
hold off

subplot(2,2,3);
contourf(x/1000.0,y/1000.0,-draft',40,'EdgeColor','None');colorbar('FontSize',fs3);
set(gca,'FontSize',fs3);
colormap jet;
xlabel('Across shelf distance (km)','FontSize',fs3);
ylabel('Along shelf distance (km)','FontSize',fs3);
title('Contours of Ice Draft (m)','FontSize',fs3);
hold off

subplot(2,2,4);
%contourf(x/1000.0,y/1000.0,-draft',40,'EdgeColor','None');colorbar('FontSize',fs3);
%set(gca,'FontSize',fs3);
%colormap jet;
%xlabel('Across shelf distance (km)','FontSize',fs3);
%ylabel('Along shelf distance (km)','FontSize',fs3);
%title('Contours of Ice Draft (m)','FontSize',fs3);
%hold off

contourf(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
         dice.Ygrid(:,j_start:j_stop)/1000.0, ...
         y_adv, ...
         25,'EdgeColor','None');colorbar('FontSize',fs3);

%contourf(dice.Xgrid(:,j_start:j_stop)/1000.0, ...
%         dice.Ygrid(:,j_start:j_stop)/1000.0, ...
%         ice_adv, ...
%         25,'EdgeColor','None');colorbar('FontSize',fs3);
set(gca,'FontSize',fs2);
xlabel('Across shelf distance (km)','FontSize',fs3)
ylabel('Along shelf distance (km)','FontSize',fs3);
title('Thickness time tendency due to ice advection term v_0 H_y','FontSize',fs3);    

%subplot(2,2,3);
%hold on
%contourf(x/1000.0,y/1000.0,T_forcing',40,'EdgeColor','None') ;colorbar('FontSize',fs33);
%set(gca,'FontSize',fs3);
%xlabel('Across shelf distance (km)','FontSize',fs3);
%title('Thermal forcing (^\circ C)','FontSize',fs3);
%hold off

fname = strcat([fig_dir,'/plume_',flabel,'_4panel_melt']);
print('-depsc',fname);
end


if (true)
figure(1);
clf;
set(fig1,'Position',[1 1 solo_fig_x_size solo_fig_y_size]);
hold on
contourf(x/1000.0,y/1000.0,-draft',40,'EdgeColor','None');colorbar('FontSize',fs);
set(gca,'FontSize',fs2);
quiver(dice.xstag(1:stride2:end)/1000, ...
       dice.ystag(1:stride2:end)/1000,...
       ice_u(1:stride2:end,1:stride2:end)',...
       ice_v(1:stride2:end,1:stride2:end)'-0.0,...
       scale,'k','LineWidth',lw);
colormap jet;
xlabel('Across shelf distance (km)','FontSize',fs);
ylabel('Along shelf distance (km)','FontSize',fs);
caxis([0 600]);
title('Contours of Ice Draft (m) with ice velocities','FontSize',fs);
hold off
print('-depsc',strcat([fig_dir,'/plume_',flabel,'_draft_ice_vel']));
end

end

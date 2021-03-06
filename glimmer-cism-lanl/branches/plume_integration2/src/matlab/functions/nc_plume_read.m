function [data] = nc_plume_read(nc_filename,istart,timestride,iend)

    has_bmelt_avg = false;

    nc = netcdf.open(nc_filename, 'NC_NOWRITE');
    
    su_id = netcdf.inqVarID(nc, 'su');
    sv_id = netcdf.inqVarID(nc, 'sv');
    u_id = netcdf.inqVarID(nc, 'u');
    v_id = netcdf.inqVarID(nc, 'v');
    time_id = netcdf.inqVarID(nc, 'time');
    bmelt_id = netcdf.inqVarID(nc, 'bmelt');

    if (nc_has_var(nc_filename,'bmelt_avg'))
       bmelt_avg_id = netcdf.inqVarID(nc, 'bmelt_avg');
       has_bmelt_avg = true;
    end

    bpos_id = netcdf.inqVarID(nc, 'bpos');    
    pdep_id = netcdf.inqVarID(nc, 'pdep');    
    train_id = netcdf.inqVarID(nc, 'train');
    entr_id = netcdf.inqVarID(nc, 'entr');
    temp_id = netcdf.inqVarID(nc,'temp');
    salt_id = netcdf.inqVarID(nc,'salt');
    rhop_id = netcdf.inqVarID(nc,'rhop');
    grav_speed_id = netcdf.inqVarID(nc,'gwave_speed');
    x_id = netcdf.inqVarID(nc, 'x');
    y_id = netcdf.inqVarID(nc, 'y');

    time_dim_id = netcdf.inqDimID(nc,'time');
    time_var_id = netcdf.inqVarID(nc,'time');
    
    [tname,tlen] = netcdf.inqDim(nc,time_dim_id);

    if (istart < 0)
      if (iend > 0) 
	error('Does not make send to have istart < 0 and iend > 0');
      end
      istart = tlen-2;
      stride = 1;
    end
    if (iend < 0)
      iend = tlen-1;
    end

    n_timeslices = floor((iend-istart)/timestride)+1;
    
    time = netcdf.getVar(nc,time_var_id,istart,n_timeslices,timestride);
    x = netcdf.getVar(nc, x_id);
    y = netcdf.getVar(nc, y_id);

    m = size(x,1);
    n = size(y, 1);

    bpos = netcdf.getVar(nc, bpos_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    pdep = netcdf.getVar(nc, pdep_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    bmelt = netcdf.getVar(nc, bmelt_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    train = netcdf.getVar(nc, train_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    entr = netcdf.getVar(nc, entr_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    su = netcdf.getVar(nc, su_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    sv = netcdf.getVar(nc, sv_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    u = netcdf.getVar(nc, u_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    v = netcdf.getVar(nc, v_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    temp = netcdf.getVar(nc, temp_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    salt = netcdf.getVar(nc, salt_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
    rhop = netcdf.getVar(nc, rhop_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
     
if (has_bmelt_avg)
    bmelt_avg = netcdf.getVar(nc, bmelt_avg_id, [0 0 istart],[m n n_timeslices],[1 1 timestride]);
end
    netcdf.close(nc);

    waterdepth = max(max(bpos(:,:,1)));

    data.x = x((1+3+2):(end-3-2));
    data.y = y((1+3):(end-4));
    [xgrid,ygrid] = meshgrid(data.x,data.y);
    data.xgrid = xgrid';
    data.ygrid = ygrid';
    data.time = time;

    f = @(M) M((1+3+2):(end-3-2),(1+3):(end-4),:);

    data.bpos = f(bpos);
    data.pdep = f(pdep);
    data.bmelt = f(bmelt);
if(has_bmelt_avg)
  data.bmelt_avg = f(bmelt_avg);
data.has_bmelt_avg = true;
 else
   data.has_bmelt_avg = false;
end
    
    data.train = f(train);
    data.entr = f(entr);
    data.su = f(su);
    data.sv = f(sv);
    data.u = f(u);
    data.v = f(v);
    data.temp = f(temp);
    data.salt = f(salt);
    data.rhop = f(rhop);
    
    data.draft = data.bpos - waterdepth;
    data.ambdepth = data.draft - data.pdep;
    [X,Y] = meshgrid(data.x,data.y);
    [data.gradx,data.grady,data.grad] = local_grad(X',Y',data.bpos);
    
dx = data.x(2)-data.x(1);
dy = data.y(2)-data.y(1);

uy = (data.su(1:(end-2)  ,3:end    ,:) + ...
      data.su(2:end-1    ,3:end    ,:) - ...
      data.su(1:(end-2)  ,1:(end-2),:) - ...
      data.su(2:end-1    ,1:(end-2),:))/(2*dy);

vx = (data.sv(3:end    ,1:(end-2)  ,:)+ ...
      data.sv(3:end    ,2:end-1    ,:)- ...
      data.sv(1:(end-2),1:(end-2)  ,:)- ...
      data.sv(1:(end-2),2:end-1    ,:))/(2*dx);
  
data.vorticity = zeros(size(data.bpos,1),size(data.bpos,2),size(data.bpos,3));
size(vx);
size(uy);
data.vorticity(2:end-1,2:end-1,:) = vx - uy;

end

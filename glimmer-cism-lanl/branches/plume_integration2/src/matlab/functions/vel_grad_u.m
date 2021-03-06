function res = vel_grad_u(su,sv,dx,dy)

  %%% idea: uu_x + vu_y = div((uu,uv)) - u div(u,v)

  [m,n] = size(su);
  m = m+1;

  %estimate of div(uu,uv)
    div1=(sv(2:end-1,2:end  ,:).*0.25.*(su(1:end-1,2:end-1,:)+...
					su(2:end  ,2:end-1,:)+...
					su(1:end-1,3:end  ,:)+...
					su(2:end  ,3:end  ,:)) ...
         -sv(2:end-1,1:end-1,:).*0.25.*(su(1:end-1,1:end-2,:)+...
                       	                su(2:end  ,1:end-2,:)+...
					su(1:end-1,2:end-1,:)+...
					su(2:end  ,2:end-1,:)) ) /dy + ...
         ( su(2:end,2:end-1,:).^2 - su(1:end-1,2:end-1,:).^2) / dx;  

% estimate of u div(u,v)
  div2 = 0.5*(su(1:end-1,2:end-1,:)+su(2:end,2:end-1,:)) .* ...
  ((su(2:end  ,2:end-1,:) - su(1:end-1,2:end-1,:))/dx + ...
   (sv(2:end-1,2:end  ,:) - sv(2:end-1,1:end-1,:))/dy);

res = zeros(m,n);
res(2:end-1,2:end-1) = div1-div2;



end

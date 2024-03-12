function [Pg_mutual]=P_new_mut(h,d,eps1,mu1,sigma1,f,con,kx)

if nargin==7
    kx=0; %sets default to zero
end

% Function for the Mutual Potential Coefficients with overhead-underground
% arrangement using the new formula

% Inputs
% h       : depth of conductor [m]
% d       : distances between conductors [m]
% e_g     : permittivity of earth [F/m]
% m_g     : permeability of earth [H/m]
% sigma_g : conductivity of earth [S/m]
% omega   : angular frequency [rad/s]

% Output
% out: Mutual earth potential coefficients between overhead/underground conductors [Ohm/m]

% Constants
sig0=0;
eps0=8.8541878128e-12;
mu0=4*pi*1e-7;
w=2*pi*f;

if strcmp(kx,'k1')
    k_x=@(omega) omega.*sqrt(mu1.*(eps1-1i.*(sigma1./omega)));
elseif strcmp(kx,'k0')
    k_x=@(omega) omega.*sqrt(mu0.*eps0);
else
    k_x=@(omega) omega.*0;
end

gamma_0=@(omega) sqrt(1i.*omega.*mu0.*(sig0+1i.*omega.*eps0));
gamma_1=@(omega) sqrt(1i.*omega.*mu1.*(sigma1+1i.*omega.*eps1));
a_0=@(lambda,omega) sqrt(lambda.^2+gamma_0(omega).^2+k_x(omega).^2);
a_1=@(lambda,omega) sqrt(lambda.^2+gamma_1(omega).^2+k_x(omega).^2);

Pg_mutual=zeros(con,con);

for x=1:1:con
    for y=1:1:con
        if x~=y
            h1=h(1,x);
            h2=h(1,y);

            if (h1 < 0 && h2 > 0) %Y10
                yy=@(a0,a1,gamma0,gamma1,hi,hj,lambda,mu0,mu1,omega,y)(mu0.*mu1.*omega.*exp(a1.*hi-a0.*hj).*cos(lambda.*y).*(sign(hi)-1.0).*(a0.*mu0+a1.*mu1).*-5.0e-1i)./(pi.*(a0.*gamma1.^2.*mu0+a1.*gamma0.^2.*mu1).*(a0.*mu1+a1.*mu0));
            elseif (h1 > 0 && h2 < 0) %Y01
                yy=@(a0,a1,gamma0,gamma1,hi,hj,lambda,mu0,mu1,omega,y)(mu0.*mu1.*omega.*exp(-a0.*hi+a1.*hj).*cos(lambda.*y).*(sign(hi)+1.0).*(a0.*mu0+a1.*mu1).*5.0e-1i)./(pi.*(a0.*gamma1.^2.*mu0+a1.*gamma0.^2.*mu1).*(a0.*mu1+a1.*mu0));
            else
                continue
            end

            yfun=@(lambda,omega) sum([0 yy(a_0(lambda,omega),a_1(lambda,omega),gamma_0(omega),gamma_1(omega),h1,h2,lambda,mu0,mu1,omega,d(x,y))],'omitnan');
            yfun=@(lambda) yfun(lambda,w);

                        Qm=integral(yfun,0,Inf,'ArrayValued',true);

                        Pg_mutual(x,y)=1i*w*Qm;
%             dij = sqrt((h1-h2)^2+d(x,y)^2);
%             Dij = sqrt((h1+h2)^2+d(x,y)^2);
%             Pg_mutual(x,y) = 1/(2*pi*eps0)*(log(Dij/dij));
        end
    end
end
end

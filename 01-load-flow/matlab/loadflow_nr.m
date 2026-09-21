function res = loadflow_nr(busdata, linedata, baseMVA, tol, maxit)
%LOADFLOW_NR  Newton-Raphson AC load flow (polar form).
%
%   busdata  : [bus type V0 Pg Pd Qd Qsh]
%              type 1 = slack, 2 = PV, 3 = PQ
%              V0   = voltage magnitude setpoint / flat-start value (pu)
%              Pg   = scheduled generation (MW)
%              Pd,Qd= load (MW, Mvar)
%              Qsh  = shunt capacitor injection at 1.0 pu (Mvar)
%   linedata : [from to R X Btotal]   (pu on baseMVA, Btotal = total line charging)
%   baseMVA  : system MVA base (default 100)

if nargin < 3, baseMVA = 100; end
if nargin < 4, tol = 1e-8; end
if nargin < 5, maxit = 30; end

nb    = size(busdata, 1);
type  = busdata(:, 2);
V     = busdata(:, 3);
theta = zeros(nb, 1);
Psp   = (busdata(:, 4) - busdata(:, 5)) / baseMVA;   % net scheduled P (pu)
Qsp   = (-busdata(:, 6)) / baseMVA;                  % net scheduled Q (pu)
Qsh   = busdata(:, 7) / baseMVA;

% ---- Build Ybus -------------------------------------------------------
Ybus = zeros(nb);
for k = 1:size(linedata, 1)
    i = linedata(k, 1);  j = linedata(k, 2);
    y = 1 / (linedata(k, 3) + 1i * linedata(k, 4));
    b = 1i * linedata(k, 5) / 2;
    Ybus(i, i) = Ybus(i, i) + y + b;
    Ybus(j, j) = Ybus(j, j) + y + b;
    Ybus(i, j) = Ybus(i, j) - y;
    Ybus(j, i) = Ybus(j, i) - y;
end
Ybus = Ybus + diag(1i * Qsh);
G = real(Ybus);  B = imag(Ybus);

pq  = find(type == 3);      % PQ buses
ang = find(type ~= 1);      % all non-slack buses (angle unknowns)

% ---- Newton-Raphson iterations -----------------------------------------
converged = false;
for iter = 1:maxit
    Vc = V .* exp(1i * theta);
    S  = Vc .* conj(Ybus * Vc);
    P  = real(S);  Q = imag(S);

    mis = [Psp(ang) - P(ang); Qsp(pq) - Q(pq)];
    if max(abs(mis)) < tol
        converged = true;
        break
    end

    H = zeros(nb); N = zeros(nb); M = zeros(nb); L = zeros(nb);
    for i = 1:nb
        for j = 1:nb
            d = theta(i) - theta(j);
            if i ~= j
                H(i,j) =  V(i)*V(j)*(G(i,j)*sin(d) - B(i,j)*cos(d));
                N(i,j) =  V(i)*(G(i,j)*cos(d) + B(i,j)*sin(d));
                M(i,j) = -V(i)*V(j)*(G(i,j)*cos(d) + B(i,j)*sin(d));
                L(i,j) =  V(i)*(G(i,j)*sin(d) - B(i,j)*cos(d));
            else
                H(i,i) = -Q(i) - B(i,i)*V(i)^2;
                N(i,i) =  P(i)/V(i) + G(i,i)*V(i);
                M(i,i) =  P(i) - G(i,i)*V(i)^2;
                L(i,i) =  Q(i)/V(i) - B(i,i)*V(i);
            end
        end
    end

    J  = [H(ang, ang), N(ang, pq); M(pq, ang), L(pq, pq)];
    dx = J \ mis;
    theta(ang) = theta(ang) + dx(1:numel(ang));
    V(pq)      = V(pq)      + dx(numel(ang)+1:end);
end

if ~converged
    warning('loadflow_nr:noConvergence', ...
            'Newton-Raphson did not converge in %d iterations.', maxit);
end

% ---- Post-processing ---------------------------------------------------
Vc = V .* exp(1i * theta);
S  = Vc .* conj(Ybus * Vc) * baseMVA;        % net injection (MW + j Mvar)

nl = size(linedata, 1);
Sf = zeros(nl, 1);  St = zeros(nl, 1);
for k = 1:nl
    i = linedata(k, 1);  j = linedata(k, 2);
    y = 1 / (linedata(k, 3) + 1i * linedata(k, 4));
    b = 1i * linedata(k, 5) / 2;
    Iij = (Vc(i) - Vc(j)) * y + Vc(i) * b;
    Iji = (Vc(j) - Vc(i)) * y + Vc(j) * b;
    Sf(k) = Vc(i) * conj(Iij) * baseMVA;
    St(k) = Vc(j) * conj(Iji) * baseMVA;
end

res.V         = V;
res.thetaDeg  = theta * 180 / pi;
res.Ybus      = Ybus;
res.iterations = iter - 1;
res.converged = converged;
res.slackP    = real(S(type == 1)) + busdata(type == 1, 5);  % MW
res.slackQ    = imag(S(type == 1)) + busdata(type == 1, 6);  % Mvar
res.Sf        = Sf;                 % flow sent at 'from' end (MW + j Mvar)
res.St        = St;                 % flow sent at 'to' end
res.lossMW    = sum(real(Sf + St));
res.lossMvar  = sum(imag(Sf + St));
end

function [] = makeULModel(Z,Y,f,line_length,ERR,Npoles)

ZYprnt=false;

transp=@(x) x';

%% Dados

if size(f,1) == 1
    frequency=f.';
else
    frequency=f;
end

w = 2*pi.*frequency; % % cálculo da frequência angular (rad/seg)
s = 1j.*w; % cálculo da frequência angular complexa
freq_siz = size(frequency,1); % número de amostras da frequência
ord=size(Z,2);

%% Calculando matriz de transformação dependente da frequência

% Raw impedance and admittance matrices
if size(Z,3)==freq_siz
    Z=permute(Z,[3 1 2]);
    Y=permute(Y,[3 1 2]);
end

[modif_T,g_dis]=LM_calc_norm_str(ord,freq_siz,Z,Y,frequency); % obtem as matrizes de transformação pelo Levenberg-Marquardt (LM)

Ti = zeros(size(Z,3), size(Z,3), size(frequency,1));
invTi = zeros(size(Z,3), size(Z,3), size(frequency,1));
for k = 1:freq_siz
    for o = 1:ord
        Ti(o,:,k) = modif_T(k,(o-1)*ord+1:o*ord); % reorganiza as dimensões de Ti para que seja Nfases x Nfases x Namostras
    end
    invTi(:,:,k) = inv(Ti(:,:,k)); % calcula a inversa de Ti
end

%% Calculando a impedância e admitância característica e o traço de Yc

[~,~,Zch,Ych] = calc_char_imped_admit(modif_T,Z,Y,ord,freq_siz); %calculo da impedancia e admitancia caracteristica

Yc = zeros(size(Z,3), size(Z,3), size(frequency,1));
for k = 1:freq_siz
    for o = 1:ord
        Yc(o,:,k) = Ych(k,(o-1)*ord+1:o*ord); % reorganiza as dimensões de Ych para que seja Nfases x Nfases x Namostras
    end
end

traceYc = zeros(size(frequency));
Yc_t = zeros(size(Z,3), size(Z,3), size(frequency,1));
for k = 1 : size(Z,1)
    Yc_t(:,:,k) = transp(Yc(:,:,k)); % transposta da dmitância característica para usar depois para que os resultados sejam no formato [11; 12; 13; 14; 15; 16; 21; 22; 23; 24; 25; 26; 31; 32; 33; 34; 35; 36 ... 61; 62; 63; 64; 65; 66] vetor coluna
    traceYc(k) = trace( Yc(:,:,k) ); % cálculo do traço de Yc - na dissertação do Zanon fala que os polos da admitância característica são calculados pelo seu traço (soma dos elementos da diagonal principal)
end

%% Calculando a função de propagação e a velocidade de fase
[Aj] = calc_prop_fun(modif_T,g_dis,line_length,ord,freq_siz); % função que calcula a função de propagação

vel = zeros(size(frequency,1), size(Z,3));
for m = 1:ord
    vel(:,m) = (2*pi*frequency)./imag(g_dis(:,m)); % calcula a velocidade de fase
end

%% Calculando polos do traço de Yc

% Npoles = numpoles; % número de polos
Ycapprox = cell(1, numel(Npoles));

% opts usadas no metodo do VF
opts.relax = 1;      % use ajuste vetorial com restrição de não trivialidade relaxada
opts.stable = 1;     % aplicar pólos estáveis
opts.asymp = 2;      % fitting com D~=0, E=0
opts.skip_pole = 0;  % não pule o cálculo dos polos
opts.skip_res = 0;   % não pule o cálculo dos resíduos
opts.cmplx_ss = 1;   % crie um modelo de espaço de estado complexo
opts.spy1 = 0;       % sem plotagem para o primeiro estágio do VF
opts.spy2 = 0;       % criar gráfico de magnitude para ajuste de f(s)

for k = 1 : numel(Npoles)
    f = traceYc.'; % renomeando o traço de Yc e realizando sua transposta - 1 x Namostras
    s = s(:).'; % realizando a transposta de s - 1 x Namostras

    poles = linspace( frequency(1), frequency(end), Npoles(k) ); % polos iniciais - 1 x Namostras

    for j = 1:10 % número de iterações
        weight = ones(1,numel(s)); % peso - 1 x Namostras
        [SERtrYc,poles,~,fit,~] = vectfit3(f, s, poles, weight, opts); % função do VF elaborada por Gustavsen
    end
    fittedPoles = poles; % polos resultantes de Yc
end

if ZYprnt
    figure(1);
    % Plotagem mostrando que o traço de Yc e o fitting do traço de Yc obtidos pela função são iguais

    semilogx(frequency,abs(traceYc),'-b', 'linewidth', 3); hold on
    semilogx(frequency,abs(fit),'--r', 'linewidth', 3)
    legend('trace Yc', 'Fit trace Yc', 'location', 'north' )
    ylabel('trace Yc')
    xlabel('Frequency [Hz]')
    grid on
end
%% Calculando os resíduos de Yc

clear opts
opts.relax = 1;      % use ajuste vetorial com restrição de não trivialidade relaxada
opts.stable = 1;     % aplicar pólos estáveis
opts.asymp = 2;      % fitting com D~=0, E=0
opts.skip_pole = 1;  % pule o cálculo dos polos
opts.skip_res = 0;   % não pule o cálculo dos resíduos
opts.cmplx_ss = 1;   % crie um modelo de espaço de estado complexo
opts.spy1 = 0;       % sem plotagem para o primeiro estágio do VF
opts.spy2 = 0;       % criar gráfico de magnitude para ajuste de f(s)

for k = 1 : numel(Npoles)
    rYc = reshape(Yc_t, size(Yc_t,2)*size(Yc_t,1), size(Yc_t,3)); % reorganiza as dimensões de Yc_t para que fique Nfases.Nfases x Namostras % [11; 12; 13; 14; 15; 16; 21; 22; 23; 24; 25; 26; 31; 32; 33; 34; 35; 36 ... 61; 62; 63; 64; 65; 66] vetor coluna
    s = s(:).'; % realizando a transposta de s - 1 x Namostras

    poles = fittedPoles; % polos iniciais obtidos no traço de Yc

    for j = 1:1 % número de iterações
        weight = ones(1,numel(s)); % peso - 1 x Namostras
        [SERYc,poles,rmserr,Ycapprox,~] = vectfit3(rYc, s, poles, weight, opts); % função do VF elaborada por Gustavsen
    end
end

if ZYprnt
    % Plotagem de comparação entre Yc calculada no programa parâmetros e Yc aproximada pelo VF
    figure(2); clf;
    subplot(2,1,1)
    semilogx(frequency, real(rYc(1,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(2,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(3,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(4,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(5,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(1,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(2,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(3,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(4,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(5,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{1,1}', 'Yc_{1,2}', 'Yc_{1,3}', 'Yc_{1,4}', 'Yc_{1,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Real Yc')
    xlabel('Frequência (Hz)')
    grid on
    subplot(2,1,2)
    semilogx(frequency, imag(rYc(1,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(2,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(3,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(4,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(5,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(1,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(2,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(3,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(4,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(5,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{1,1}', 'Yc_{1,2}', 'Yc_{1,3}', 'Yc_{1,4}', 'Yc_{1,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Imaginário Yc')
    xlabel('Frequência (Hz)')
    grid on

    figure(3); clf;
    subplot(2,1,1)
    semilogx(frequency, real(rYc(6,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(7,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(8,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(9,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(10,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(6,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(7,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(8,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(9,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(10,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{2,1}', 'Yc_{2,2}', 'Yc_{2,3}', 'Yc_{2,4}', 'Yc_{2,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Real Yc')
    xlabel('Frequência (Hz)')
    grid on
    subplot(2,1,2)
    semilogx(frequency, imag(rYc(6,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(7,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(8,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(9,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(10,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(6,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(7,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(8,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(9,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(10,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{2,1}', 'Yc_{2,2}', 'Yc_{2,3}', 'Yc_{2,4}', 'Yc_{2,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Imaginário Yc')
    xlabel('Frequência (Hz)')
    grid on

    figure(4); clf;
    subplot(2,1,1)
    semilogx(frequency, real(rYc(11,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(12,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(13,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(14,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(15,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(11,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(12,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(13,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(14,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(15,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{3,1}', 'Yc_{3,2}', 'Yc_{3,3}', 'Yc_{3,4}', 'Yc_{3,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Real Yc')
    xlabel('Frequência (Hz)')
    grid on
    subplot(2,1,2)
    semilogx(frequency, imag(rYc(11,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(12,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(13,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(14,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(15,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(11,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(12,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(13,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(14,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(15,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{3,1}', 'Yc_{3,2}', 'Yc_{3,3}', 'Yc_{3,4}', 'Yc_{3,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Imaginário Yc')
    xlabel('Frequência (Hz)')
    grid on

    figure(5); clf;
    subplot(2,1,1)
    semilogx(frequency, real(rYc(16,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(17,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(18,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(19,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(20,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(16,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(17,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(18,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(19,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(20,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{4,1}', 'Yc_{4,2}', 'Yc_{4,3}', 'Yc_{4,4}', 'Yc_{4,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Real Yc')
    xlabel('Frequência (Hz)')
    grid on
    subplot(2,1,2)
    semilogx(frequency, imag(rYc(16,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(17,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(18,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(19,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(20,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(16,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(17,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(18,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(19,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(20,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{4,1}', 'Yc_{4,2}', 'Yc_{4,3}', 'Yc_{4,4}', 'Yc_{4,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Imaginário Yc')
    xlabel('Frequência (Hz)')
    grid on

    figure(6); clf;
    subplot(2,1,1)
    semilogx(frequency, real(rYc(21,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(22,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(23,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(24,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, real(rYc(25,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(21,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(22,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(23,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(24,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Ycapprox(25,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{5,1}', 'Yc_{5,2}', 'Yc_{5,3}', 'Yc_{5,4}', 'Yc_{5,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Real Yc')
    xlabel('Frequência (Hz)')
    grid on
    subplot(2,1,2)
    semilogx(frequency, imag(rYc(21,:).'), '-k', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(22,:).'), '-b', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(23,:).'), '-g', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(24,:).'), '-c', 'linewidth', 3); hold on
    semilogx(frequency, imag(rYc(25,:).'), '-m', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(21,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(22,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(23,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(24,:).'), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Ycapprox(25,:).'), ':r', 'linewidth', 3); hold on
    legend('Yc_{5,1}', 'Yc_{5,2}', 'Yc_{5,3}', 'Yc_{5,4}', 'Yc_{5,5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Imaginário Yc')
    xlabel('Frequência (Hz)')
    grid on
end

%% Calculando Pj com tau otimizado

% opts usadas no metodo do VF
clear opts
opts.relax = 1;      % use ajuste vetorial com restrição de não trivialidade relaxada
opts.stable = 1;     % aplicar pólos estáveis
opts.skip_pole = 0;  % não pule o cálculo dos polos
opts.skip_res = 0;   % não pule o cálculo dos resíduos
opts.cmplx_ss = 1;   % crie um modelo de espaço de estado complexo
opts.spy1 = 0;       % sem plotagem para o primeiro estágio do VF
opts.spy2 = 0;       % criar gráfico de magnitude para ajuste de f(s)
opts.logx = 1;       % usar eixo logarítmico de abcissas
opts.logy = 1;       % usar eixo de ordenadas logarítmicas
opts.errplot = 1;    % incluir desvio no gráfico de magnitude
opts.phaseplot = 0;  % também produz plotagem do ângulo de fase (além da magnitude)
opts.legend = 1;     % inclua legendas nos gráficos
opts.asymp = 1;      % fitting com D=0, E=0
opts.weightscheme = 3; % pesos 1 = uniform weights; 2 = inv(sqrt(norm)) 3 = inv(norm)
opts.firstguesstype = 1; % polos de valor real - usado no VF wrapper
opts.output_messages = false; % - usado no VF wrapper
opts.passive = 0; % - usado no VF wrapper

% ERR = .1/100; % tolerância do erro
for m = 1:ord
    [~, ~, ~, ~, ~, ~, ~, tau_opt, ~, fun] = findoptimtau_ulm(frequency,vel(:,m),Aj(:,m),line_length,ERR,opts); % função que faz o VF da função de propagação considerando o tau ótimo, nesse caso uso para obter o Pj com tau otimizado

    fitOHLT_H(m).tau_opt = tau_opt; % tau otimizado
    fitOHLT_H(m).fun = fun; % Pj = H.*exp(1i.*2.*pi.*f.*tau) -  eq. 3.22 dissertação zanon;
end

P_j = zeros(ord,length(frequency));
P_j_t = zeros(length(frequency),ord);
for i = 1:ord
    for j = 1:length(frequency)
        P_j(i,j) = fitOHLT_H(i).fun(j,:); % passando Pj para forma Nfases x Namostras para usar no fitting
        P_j_t(j,i) = P_j(i,j).'; % transposta de Pj
    end
end

Pj = zeros(size(Yc));
for k=1:freq_siz
    Pj(:,:,k)=diag(P_j_t(k,:)); % transformando Pj em uma matriz diagonal para usar depois no cálculo de DjPj
end

%% Calculando fitting de Pj

clear opts
opts.relax = 1;      % use ajuste vetorial com restrição de não trivialidade relaxada
opts.stable = 1;     % aplicar pólos estáveis
opts.asymp = 1;      % fitting com D=0, E=0
opts.skip_pole = 0;  % pule o cálculo dos polos
opts.skip_res = 0;   % não pule o cálculo dos resíduos
opts.cmplx_ss = 1;   % crie um modelo de espaço de estado complexo
opts.spy1 = 0;       % sem plotagem para o primeiro estágio do VF
opts.spy2 = 0;       % criar gráfico de magnitude para ajuste de f(s)

for k = 1 : numel(Npoles)
    s = s(:).'; % realizando a transposta de s - 1 x Namostras
    Pjj = P_j; % renomeando P_j Nfases x Namostras

    poles = linspace( frequency(1), frequency(end), Npoles(k) ); % polos iniciais - 1 x Namostras

    for j = 1:10 % número de iterações
        weight = ones(1,numel(s)); % peso - 1 x Namostras
        [SERPj,poles,~,Pjapprox,~] = vectfit3(Pjj, s, poles, weight, opts); % função do VF elaborada por Gustavsen
    end
    polesPj = poles; % polos resultantes de Yc
end

if ZYprnt
    % Plotagem de comparação entre Pj e Pj aproximada pelo VF
    figure(7); clf;
    subplot(2,1,1)
    semilogx(frequency, real(Pjj(1,:)), '-k', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjj(2,:)), '-b', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjj(3,:)), '-g', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjj(4,:)), '-c', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjj(5,:)), '-m', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjapprox(1,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjapprox(2,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjapprox(3,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjapprox(4,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, real(Pjapprox(5,:)), ':r', 'linewidth', 3); hold on
    legend('Pj_{modo1}', 'Pj_{modo2}', 'Pj_{modo3}', 'Pj_{modo4}', 'Pj_{modo5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Real Pj')
    xlabel('Frequência (Hz)')
    grid on
    subplot(2,1,2)
    semilogx(frequency, imag(Pjj(1,:)), '-k', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjj(2,:)), '-b', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjj(3,:)), '-g', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjj(4,:)), '-c', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjj(5,:)), '-m', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjapprox(1,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjapprox(2,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjapprox(3,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjapprox(4,:)), ':r', 'linewidth', 3); hold on
    semilogx(frequency, imag(Pjapprox(5,:)), ':r', 'linewidth', 3); hold on
    legend('Pj_{modo1}', 'Pj_{modo2}', 'Pj_{modo3}', 'Pj_{modo4}', 'Pj_{modo5}', ['Ajustado - ' num2str(Npoles) ' polos'], 'location', 'north' )
    ylabel('Imaginário Pj')
    xlabel('Frequência (Hz)')
    grid on
end

%% Calculando os resíduos de DjPj

for m=1:ord
    for k=1:freq_siz
        mode(m).D(:,:,k)=Ti(:,m,k)*invTi(m,:,k); % matriz Dj idempotentes
    end
end

clear opts
opts.relax = 1;      % use ajuste vetorial com restrição de não trivialidade relaxada
opts.stable = 1;     % aplicar pólos estáveis
opts.asymp = 1;      % fitting com D=0, E=0
opts.skip_pole = 1;  % pule o cálculo dos polos
opts.skip_res = 0;   % não pule o cálculo dos resíduos
opts.cmplx_ss = 1;   % crie um modelo de espaço de estado complexo
opts.spy1 = 0;       % sem plotagem para o primeiro estágio do VF
opts.spy2 = 0;       % criar gráfico de magnitude para ajuste de f(s)

for o = 1:ord
    clear DjPj
    for k = 1:freq_siz
        DjPj(:,:,k) = mode(o).D(:,:,k)*Pj(o,o,k); % Dj.Pj - eq. 3.23 dissertação zanon
        DjPj_t(:,:,k) = transp(DjPj(:,:,k)); % transposta de DjPj
    end
    for k = 1 : numel(Npoles)
        rDjPj = reshape(DjPj_t, size(DjPj_t,2)*size(DjPj_t,1), size(DjPj_t,3)); % reorganiza as dimensões de Yc_t para que fique (Nfases*Nfases) x Namostras % [11; 12; 13; 14; 15; 16; 21; 22; 23; 24; 25; 26; 31; 32; 33; 34; 35; 36 ... 61; 62; 63; 64; 65; 66] vetor coluna
        s = s(:).'; % realizando a transposta de s - 1 x Namostras

        poles = polesPj; % polos iniciais obtidos no Pj

        for j = 1:1
            weight = ones(1,numel(s)); % peso - 1 x Namostras
            [SERH,poles,~,Happrox,~] = vectfit3(rDjPj, s, poles, weight, opts); % função do VF elaborada por Gustavsen

            Cij(:,:,o) = SERH.C;

            if ZYprnt

                figure(10); clf;
                subplot(2,1,1)
                semilogx(frequency, real(rDjPj(1,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(2,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(3,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(4,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(5,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(1,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(2,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(3,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(4,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(5,:)), ':r', 'linewidth', 3); hold on
                ylabel('Real de DjPj')
                xlabel('Frequência (Hz)')
                grid on
                subplot(2,1,2)
                semilogx(frequency, imag(rDjPj(1,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(2,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(3,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(4,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(5,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(1,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(2,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(3,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(4,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(5,:)), ':r', 'linewidth', 3); hold on
                ylabel('Imaginário de DjPj')
                xlabel('Frequência (Hz)')
                grid on

                figure(11); clf;
                subplot(2,1,1)
                semilogx(frequency, real(rDjPj(6,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(7,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(8,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(9,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(10,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(6,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(7,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(8,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(9,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(10,:)), ':r', 'linewidth', 3); hold on
                ylabel('Real de DjPj')
                xlabel('Frequência (Hz)')
                grid on
                subplot(2,1,2)
                semilogx(frequency, imag(rDjPj(6,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(7,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(8,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(9,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(10,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(6,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(7,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(8,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(9,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(10,:)), ':r', 'linewidth', 3); hold on
                ylabel('Imaginário de DjPj')
                xlabel('Frequência (Hz)')
                grid on

                figure(12); clf;
                subplot(2,1,1)
                semilogx(frequency, real(rDjPj(11,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(12,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(13,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(14,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(15,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(11,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(12,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(13,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(14,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(15,:)), ':r', 'linewidth', 3); hold on
                ylabel('Real de DjPj')
                xlabel('Frequência (Hz)')
                grid on
                subplot(2,1,2)
                semilogx(frequency, imag(rDjPj(11,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(12,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(13,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(14,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(15,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(11,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(12,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(13,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(14,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(15,:)), ':r', 'linewidth', 3); hold on
                ylabel('Imaginário de DjPj')
                xlabel('Frequência (Hz)')
                grid on

                figure(13); clf;
                subplot(2,1,1)
                semilogx(frequency, real(rDjPj(16,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(17,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(18,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(19,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(20,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(16,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(17,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(18,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(19,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(20,:)), ':r', 'linewidth', 3); hold on
                ylabel('Real de DjPj')
                xlabel('Frequência (Hz)')
                grid on
                subplot(2,1,2)
                semilogx(frequency, imag(rDjPj(16,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(17,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(18,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(19,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(20,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(16,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(17,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(18,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(19,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(20,:)), ':r', 'linewidth', 3); hold on
                ylabel('Imaginário de DjPj')
                xlabel('Frequência (Hz)')
                grid on

                figure(14); clf;
                subplot(2,1,1)
                semilogx(frequency, real(rDjPj(21,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(22,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(23,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(24,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, real(rDjPj(25,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(21,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(22,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(23,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(24,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, real(Happrox(25,:)), ':r', 'linewidth', 3); hold on
                ylabel('Real de DjPj')
                xlabel('Frequência (Hz)')
                grid on
                subplot(2,1,2)
                semilogx(frequency, imag(rDjPj(21,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(22,:)), '-b', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(23,:)), '-g', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(24,:)), '-c', 'linewidth', 3); hold on
                semilogx(frequency, imag(rDjPj(25,:)), '-k', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(21,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(22,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(23,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(24,:)), ':r', 'linewidth', 3); hold on
                semilogx(frequency, imag(Happrox(25,:)), ':r', 'linewidth', 3); hold on
                ylabel('Imaginário de DjPj')
                xlabel('Frequência (Hz)')
                grid on
            end

        end
    end
end

%% Para escrever os polos e residuos de Yc e H em txt

ii = 1;
for m = 1:ord
    [b, ~] = size(fitOHLT_H(m).tau_opt); % reorganiza as dimensões de fitOHLT_H(m).tau_opt para que fique número de taus total (somando todos os modos) x 1 - ex LT trifásica (3 x 1)
    D_aux(:,1) =  fitOHLT_H(m).tau_opt;
    for i = 1:b
        D(ii,1) = D_aux(i,1);
        ii = ii + 1;
    end
    clear D_aux
end

pol = fittedPoles.';
polPj = polesPj.';
rYc = reshape(SERYc.C, size(SERYc.C,1)*size(SERYc.C,2), 1); % reorganiza as dimensões de SERYc.C para que fique nfases.nfases.npolos x 1
rCij = reshape(Cij, size(Cij,1)*size(Cij,2), size(Cij,3)); % reorganiza as dimensões de Cij para que fique nfases.nfases.npolos x nmodos
rresiduos = reshape(rCij, size(rCij,1)*size(rCij,2), 1); % reorganiza as dimensões de SERYc.C para que fique nfases.nfases.npolos.modos x 1

filename='fitULM000001.txt';

fid = fopen(filename,'wt');
fprintf(fid,'%d\n',size(Yc,1)); %numero de fases
fprintf(fid,'%d\n',size(Yc,1)); %numero de modos
fprintf(fid,'%d\n',size(pol,1)); %numero de polos Yc
fprintf(fid,'%d\n',size(polPj,1)); %numero de polos A

%polYcvet
for ii = 1:size(pol,1)
    fprintf(fid,'%.16e\t%.16e\n',real(pol(ii)),imag(pol(ii)));
end
%resYc
for kk = 1:size(rYc,1)
    fprintf(fid,'%.16e\t%.16e\n',real(rYc(kk)),imag(rYc(kk)));
end
%polA
for ii = 1:size(polPj,1)
    fprintf(fid,'%.16e\t%.16e\n',real(polPj(ii)),imag(polPj(ii)));
end
%resA
for kk = 1:size(rresiduos,1)
    fprintf(fid,'%.16e\t%.16e\n',real(rresiduos(kk)),imag(rresiduos(kk)));
end
% taus otimizados
for jj = 1:size(D,1)
    fprintf(fid,'%.16e\n',D(jj));
end
% resid0Yc
for ii = 1:(size(SERYc.D,1))
    fprintf(fid,'%.16e\t%.16e\n',real(SERYc.D(ii)),imag(SERYc.D(ii)));
end
fclose(fid);

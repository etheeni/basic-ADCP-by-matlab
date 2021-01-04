clear;
clc;
close all;

%% m ���в��� 7 ����Ԫ
BaseVal     = 2;        % ����
PowerVal    = 3;        % �״Σ��̣�
N           = 10;        % ��Ԫ�ظ�������
Shift       = [];       % ��Ԫ��λ��Ŀ
WhichSeq    = 1;        % ��ԭ����ʽѡ��
Mseq        = Mseq_function(BaseVal, PowerVal, N, Shift, WhichSeq);
Code_N      = BaseVal ^ PowerVal - 1;   % ��Ԫ����

%% ��M�������37.5kHz�������źţ�ÿ����Ԫ���10�����ڵ������ź�
Fc          = 1 * 37.5e3;       % �źŵ�����Ƶ��
Fs          = 4 * Fc;       % �źŵĲ���Ƶ��
Tc          = 1 / Fc;       % �ź�����
Ts          = 1 / Fs;       % �źŵ��ز������
Period_N    = 5;           % ÿ����Ԫ�������ź����������̣�
OneCodeSampNum      = Period_N * Fs / Fc;       % ������Ԫ��ӵ�еĲ�������

%% ����������Ƶ��֮��Ļز��ź�
V       = 5.1;       % Ŀ���ٶ�
c       = 1500;     % ����
Fd      = round((c + V) / (c - V) * Fc);            % ���ж����յ�Ƶ��
DeltaF  = (2*10) / (c - 10) * Fc;
PeriodMSeq  = N;                                    % M ���е�������
NumSampled  = OneCodeSampNum * Code_N * PeriodMSeq; % ��������M���еĲ�������
SignalSend  = zeros( NumSampled, 1 );               % �����źŴ洢�ռ����

% for nn = 1:1:Code_N * PeriodMSeq
%     t1 = (nn - 1) * OneCodeSampNum * Ts : Ts : (nn * OneCodeSampNum  - 1) * Ts; % t1��0��ʼ��
%     SignalSend((nn - 1) * OneCodeSampNum  + 1 : 1 : nn * OneCodeSampNum ) = ...
%         sin(2 * pi * Fc * t1 + pi * (Mseq(nn)+ 1) / 2);
% end

for pp = 1:1:PeriodMSeq
    t0 = (pp - 1) * Code_N * Ts * OneCodeSampNum;
    for nn = 1:1:Code_N 
        t1 = t0 + (nn - 1) * OneCodeSampNum * Ts : Ts : t0 + (nn * OneCodeSampNum  - 1) * Ts; % t1��0��ʼ��
        SignalSend((pp-1)*Code_N *OneCodeSampNum + (nn - 1) * OneCodeSampNum  + 1 : 1 : (pp-1)*Code_N *OneCodeSampNum + nn * OneCodeSampNum ) = ...
            sin(2 * pi * Fc * t1 + pi * (Mseq(nn)+ 1) / 2);
    end
end

figure
plot((0:NumSampled - 1) * Ts * 1000, SignalSend);
title('Siganl Transmit');
xlabel('Time/ms');
ylabel('Amplitude');
ylim([-1.3 1.3]);
grid on;

SignalReceiced      = resample(SignalSend, Fc, Fd);
NumOneCodeSamp      = length(SignalReceiced) / N / Code_N;

%% �����źźͽ����ź�Ƶ�׷���
NFFT                = 2^nextpow2(length(SignalSend));
FFTSignalSend       = fft(SignalSend, NFFT);
FFTSignalReceiced   = fft(SignalReceiced, NFFT);
FrequencyDistri     = (0:1:NFFT / 2 - 1) * Fs / NFFT;

figure
plot(FrequencyDistri, abs(FFTSignalSend((1:1:NFFT / 2), 1)), '-o',...
     FrequencyDistri, abs(FFTSignalReceiced((1:1:NFFT / 2 ), 1)), '-*');
title('�����źźͽ����źŵ�Ƶ��');
xlabel('Frequency /Hz');
ylabel('Amplitude');
grid on;

%% ��ͨ�˲���ƣ����������
B = 1 / (1 / Fd * Period_N);    % �����źŵĴ���

rp_passband  = 0.14;            % Passband ripple
rs_passband  = 75;              % Stopband ripple
fs_passband  = 600;             % Sampling frequency

% FreqPassNorm1   = (Fs - B ) /(2 * Fs);
% FreqPassNorm2   = 1 - FreqPassNorm1;
% FreqPass1       = FreqPassNorm1 * fs_passband / 2;
% FreqPass2       = FreqPassNorm2 * fs_passband / 2;
% FreqStop1       = FreqPass1 - 10;
% FreqStop2       = FreqPass2 + 10;

FreqPassNorm1   = 2 *(Fc - (B + DeltaF) / 2 ) /(Fs);
FreqPassNorm2   = 2 *(Fc + (B + DeltaF) / 2 ) /(Fs);
FreqPass1       = FreqPassNorm1 * fs_passband / 2;
FreqPass2       = FreqPassNorm2 * fs_passband / 2;
FreqStop1       = FreqPass1 - 10;
FreqStop2       = FreqPass2 + 10;

f_passband   = [FreqStop1 FreqPass1 FreqPass2 FreqStop2];     % Cutoff frequencies
a_passband   = [0 1 0];         % Desired amplitudes

dev_passband        = [10^(-rs_passband/20) (10^(rp_passband/20)-1)/(10^(rp_passband/20)+1)  10^(-rs_passband/20)];
[n,fo,ao,w]         = firpmord(f_passband,a_passband,dev_passband,fs_passband);
b_passband          = firpm(n,fo,ao,w);         % ����˲���ϵ��

figure
freqz(b_passband,1,1024,fs_passband)

%% ���ز��źż�����
SNR     = 10;           % �����
Noise   = randn(2 * length(SignalReceiced),1);          % ��������Ϊ�źų�������������
NoiseAfterFilter = filter(b_passband.', 1, Noise);      % ��Ӵ�������
NoiseCut        = ...
    NoiseAfterFilter(length(Noise)/2 - length(SignalReceiced)/2 : length(Noise)/2 + length(SignalReceiced)/2 - 1);
% ѡȡ�����м���źŵ�����ͬ�Ĳ���
EnergyNoise     = NoiseCut' * NoiseCut;                 % ��������
EnergySignal    = SignalReceiced' * SignalReceiced;     % �źŵ�����
NoiseNorm       = NoiseCut / sqrt(EnergyNoise);         % ������һ��
SignalNorm      = SignalReceiced / sqrt(EnergySignal);  % �źŹ�һ��
CoeffSnr        = 10^(-SNR/20);
NoiseSnr        = CoeffSnr * NoiseNorm * sqrt(EnergyNoise);
SignalAddNoise  = SignalReceiced + NoiseSnr;

%% �������֤
SnrVerify = 10 * log10( EnergySignal / (NoiseSnr' * NoiseSnr));


%% ��ͨ�˲������
Rp_LowPass  = 0.05;         % Passband ripple
Rs_LowPass  = 55;          % Stopband ripple
Fs_LowPass  = 600;         % Sampling frequency

FreqPass3 = 2 * (B + DeltaF) / Fs * Fs_LowPass / 2;
FreqStop3 = FreqPass3 + 10;
F_LowPass   = [FreqPass3 FreqStop3];     % Cutoff frequencies
% F_LowPass   = [15 20];     % Cutoff frequencies
A_LowPass   = [1 0];       % Desired amplitudes

Dev_LowPass     = [(10^(Rp_LowPass/20)-1)/(10^(Rp_LowPass/20)+1),...
                    10^(-Rs_LowPass/20)];
[n,fo,ao,w]     = firpmord(F_LowPass,A_LowPass,Dev_LowPass,Fs_LowPass);
B_Lowband       = firpm(n,fo,ao,w);         % ����˲���ϵ��

figure
freqz(B_Lowband,1,1024,Fs_LowPass)

%% �������
t3              = (0:1:length(SignalReceiced)-1).'*Ts;
BaseSignal      = exp( -1i * 2 * pi * Fc * t3);
SignalDemodu    = BaseSignal .* SignalAddNoise;
SignalFiltered  = filter(B_Lowband, 1, SignalDemodu);

fftSignalFiltered = fft(SignalFiltered,Fs);
fftSignalDemodu   = fft(SignalDemodu,Fs);
figure
plot(abs(fftSignalDemodu))
hold on
plot(abs(fftSignalFiltered))
%% ����ط���Ƶ
% �ź��ӳ�8����Ԫ

Delay       = round(NumOneCodeSamp * Code_N);
Segment1    = SignalFiltered(1:1:1 + length(SignalFiltered)/2);
Segment2    = SignalFiltered(Delay + 1 : Delay + 1 + length(SignalFiltered)/2);
autocorr    = sum(Segment1.* conj(Segment2));
theta       = -atan2(imag(autocorr), real(autocorr));
EstiFreq    = theta / (2 * pi * Delay * Ts);
EstiV       = EstiFreq * c / (2 * Fc);

fprintf('����Ŀ���ٶȣ�%.3f\n', EstiV);

% WASABI_3T_001_3p7uT_1block_5ms
% Creates a sequence file for a WASABI protocol with 31 offsets and one M0 image at 3T according to:
% https://doi.org/10.1002/mrm.26133
%
% Kai Herz 2020
% kai.herz@tuebingen.mpg.de

% author name for sequence file
author = 'Kai Herz';

%% get id of generation file
if contains(mfilename, 'LiveEditorEvaluationHelperESectionEval')
    [~, seqid] = fileparts(matlab.desktop.editor.getActiveFilename);
else
    [~, seqid] = fileparts(which(mfilename));
end

%% sequence definitions
% everything in seq_defs gets written as definition in .seq-file
seq_defs.n_pulses      = 1              ; % number of pulses
seq_defs.B1rms        = 3.7            ; % b1 for 1 block is cqpe
seq_defs.tp            = 5e-3           ; % pulse duration [s]
seq_defs.Trec          = 3              ; % recovery time [s]
seq_defs.Trec_M0       = 12             ; % recovery time before M0 [s]
seq_defs.M0_offset     = -300           ; % m0 offset [ppm]
seq_defs.offsets_ppm   = [seq_defs.M0_offset linspace(-2, 2, 31)]; % offset vector [ppm]
seq_defs.num_meas      = numel(seq_defs.offsets_ppm)   ; % number of repetition
seq_defs.Tsat          = seq_defs.tp     ;  % saturation time [s]
seq_defs.FREQ		   = 127.7292 ;         % Approximately 3 T 
seq_defs.B0            = seq_defs.FREQ/(seq.sys.gamma*1e-6);  % Calculate B0    
seq_defs.seq_id_string = seqid           ; % unique seq id


%% get info from struct
offsets_ppm = seq_defs.offsets_ppm; % [ppm]
Trec        = seq_defs.Trec;        % recovery time between scans [s]
Trec_M0     = seq_defs.Trec_M0;     % recovery time before m0 scan [s]
tp          = seq_defs.tp;          % sat pulse duration [s]
n_pulses    = seq_defs.n_pulses;    % number of sat pulses per measurement. if DC changes use: n_pulses = round(2/(t_p+t_d))
B1          = seq_defs.B1rms;      % B1 [uT]
spoiling    = 1;     % 0=no spoiling, 1=before readout, Gradient in x,y,z
seq_filename = strcat(seq_defs.seq_id_string,'.seq'); % filename

%% scanner limits
% see pulseq doc for more ino
seq = SequenceSBB(getScannerLimits());

%% create scanner events
% satpulse
gamma_hz  =seq.sys.gamma*1e-6;                  % for H [Hz/uT]
gamma_rad = gamma_hz*2*pi;        % [rad/uT]
fa_sat        = B1*gamma_rad*tp; % flip angle of sat pulse

% create pulseq saturation pulse object
satPulse      = mr.makeBlockPulse(fa_sat, 'Duration', tp, 'system', seq.sys); % block pulse


%% loop through zspec offsets
offsets_Hz = offsets_ppm*seq_defs.FREQ;

% loop through offsets and set pulses and delays
for currentOffset = offsets_Hz
    if currentOffset == seq_defs.M0_offset*seq_defs.FREQ
        if Trec_M0 > 0
            seq.addBlock(mr.makeDelay(Trec_M0));
        end
    else
        if Trec > 0
            seq.addBlock(mr.makeDelay(Trec)); % recovery time
        end
    end
    % add single pulse
    satPulse.freqOffset = currentOffset; % set freuqncy offset of the pulse
    seq.addBlock(satPulse) % add sat pulse
    if spoiling % spoiling before readout
        seq.addSpoilerGradients();
    end
    seq.addPseudoADCBlock(); % readout trigger event
end

%% write definitions
def_fields = fieldnames(seq_defs);
for n_id = 1:numel(def_fields)
    seq.setDefinition(def_fields{n_id}, seq_defs.(def_fields{n_id}));
end
seq.write(seq_filename, author);

%% plot
saveSaturationPhasePlot(seq_filename);

%% call standard sim
M_z = simulate_pulseqcest(seq_filename,'../../sim-library/WM_3T_default_7pool_bmsim.yaml');

%% plot
plotSimulationResults(M_z,offsets_ppm, seq_defs.M0_offset);

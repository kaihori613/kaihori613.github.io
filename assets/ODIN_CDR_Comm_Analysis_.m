function ODIN_CDR_Comm_Analysis()

clearvars; close all; clc;

P = build_parameters();

fprintf('\n=================================================================\n');
fprintf(' ODIN CDR COMM / DATA VOLUME / CONTACT WINDOW ANALYSIS\n');
fprintf('=================================================================\n\n');
print_parameter_summary(P);

inspCases = define_inspection_cases(P);
hkCases   = define_housekeeping_cases(P);
cjCases   = define_conjunction_cases(P);

allImagePlans   = table();
allSummary      = table();
allSegments     = table();
allContacts     = table();
allDailyBacklog = table();
allSegIdx       = table();

for k = 1:numel(inspCases)
    C    = inspCases(k);
    Plan = compute_imaging_plan(P, C);

    T24  = finalize_timeline(build_inspection_day_24hr(P, C, Plan));
    T14  = finalize_timeline(build_inspection_window_14day(P, C, Plan));

    allImagePlans   = [allImagePlans;   build_image_plan_table(P, C, Plan)];      %#ok<AGROW>
    allSummary      = [allSummary;      summarize_timeline(C,'Inspection 24 hr',T24)]; %#ok<AGROW>
    allSummary      = [allSummary;      summarize_timeline(C,'Inspection 14 day',T14)];%#ok<AGROW>
    allSegments     = [allSegments;     add_case_cols(C,'Inspection 24 hr',T24)];  %#ok<AGROW>
    allSegments     = [allSegments;     add_case_cols(C,'Inspection 14 day',T14)]; %#ok<AGROW>
    allContacts     = [allContacts;     build_contact_summary(C,'Inspection 24 hr',T24)]; %#ok<AGROW>
    allContacts     = [allContacts;     build_contact_summary(C,'Inspection 14 day',T14)];%#ok<AGROW>
    allDailyBacklog = [allDailyBacklog; build_daily_backlog(C,'Inspection 14 day',T14,14)]; %#ok<AGROW>
    allSegIdx       = [allSegIdx;       build_seg_index(C,'Inspection 24 hr',T24)]; %#ok<AGROW>
    allSegIdx       = [allSegIdx;       build_seg_index(C,'Inspection 14 day',T14)];%#ok<AGROW>

    print_inspection_case(P, C, Plan, T24, T14);
    plot_inspection_24hr(P, C, Plan, T24);
    plot_inspection_14day(P, C, Plan, T14);
end

for k = 1:numel(hkCases)
    H   = hkCases(k);
    THK = finalize_timeline(build_housekeeping_24hr(P, H));

    allSummary  = [allSummary;  summarize_timeline(H,'HK 24 hr',THK)];  %#ok<AGROW>
    allSegments = [allSegments; add_case_cols(H,'HK 24 hr',THK)];        %#ok<AGROW>
    allContacts = [allContacts; build_contact_summary(H,'HK 24 hr',THK)];%#ok<AGROW>
    allSegIdx   = [allSegIdx;   build_seg_index(H,'HK 24 hr',THK)];      %#ok<AGROW>

    print_hk_case(H, THK);
    plot_hk_24hr(P, H, THK);
end

% ---- SOLAR CONJUNCTION (30-day worst-case comms blackout) ----
for k = 1:numel(cjCases)
    X    = cjCases(k);
    TCJ  = finalize_timeline(build_conjunction_window(P, X));

    allSummary  = [allSummary;  summarize_timeline(X,'Conjunction 30 day',TCJ)];   %#ok<AGROW>
    allSegments = [allSegments; add_case_cols(X,'Conjunction 30 day',TCJ)];         %#ok<AGROW>
    allContacts = [allContacts; build_contact_summary(X,'Conjunction 30 day',TCJ)]; %#ok<AGROW>
    allSegIdx   = [allSegIdx;   build_seg_index(X,'Conjunction 30 day',TCJ)];       %#ok<AGROW>

    print_conjunction_case(P, X, TCJ);
    plot_conjunction(P, X, TCJ);
end

conopsT = build_conops_table(P);
safeT   = build_safe_mode_table(P);

writetable(allImagePlans,   'Table_00_ImagePlan.csv');
writetable(allSummary,      'Table_01_DataVolume_Summary.csv');
writetable(allSegments,     'Table_02_Timeline_Segments.csv');
writetable(allContacts,     'Table_03_ContactWindow_Summary.csv');
writetable(conopsT,         'Table_04_CONOPS_Assumptions.csv');
writetable(safeT,           'Table_05_SafeMode_NoSun.csv');
writetable(allDailyBacklog, 'Table_06_Daily_SSMM_Backlog.csv');
writetable(allSegIdx,       'Table_07_Segment_Index.csv');

plot_summary_bar(allSummary);
plot_no_sun_bar(allSummary, safeT);
plot_daily_backlog(allDailyBacklog);

plot_range_vs_datarate_6dB(P);

% CDR figures

dutyPlan = compute_imaging_plan(P, inspCases(1));
plot_duty_cycle_figure(P, dutyPlan);
plot_off_sun_figure(P, dutyPlan);

fprintf('\n--- IMAGE PLAN TABLE ---\n');   disp(allImagePlans);
fprintf('\n--- DATA VOLUME SUMMARY ---\n'); disp(allSummary);
fprintf('\nCSVs saved to: %s\n', pwd);
end

% PARAMETERS 

function P = build_parameters()
P = struct();

AU_km = 149597870.7;  % km per AU

% INSPECTION GEOMETRY  
P.insp1_date     = '2028-02-16';
P.insp2_date     = '2028-11-19';
P.insp1_range_km = 114000000;          % km  (Table 5)
P.insp2_range_km = 109370000;          % km  (Table 5)
P.insp1_range_AU = P.insp1_range_km / AU_km;  % 0.7620 AU
P.insp2_range_AU = P.insp2_range_km / AU_km;  % 0.7311 AU
P.insp1_dl_kbps  = 85;                % kbps (Table 5)
P.insp2_dl_kbps  = 89;                % kbps (Table 5)

% CAMERAS 
P.cam_names      = {'ONC-W'; 'LORRI'; 'LWIR'};
P.cam_rate_kbps  = [236.1;   228.1;   224.0];    % kbps  (Table 4)
P.cam_image_MB   = [0.8853;  1.1531;  0.8400];   % MB/image (camera doc, BER included)

% Operational fps 
P.cam_op_fps     = P.cam_rate_kbps * 1e3 ./ (P.cam_image_MB * 8e6);
P.cam_cadence_s  = 1 ./ P.cam_op_fps;  

% Camera active mode flags 
% Columns: [Pre-Inspection, Approach, Inspection]
P.cam_on_preinsp = logical([1; 0; 0]);
P.cam_on_insp    = logical([1; 1; 1]);

% LASER ALTIMETER 
P.la_hk_kbps  = 0.016;   % kbps HK 
P.la_sci_kbps = 0.144;   % kbps science beyond HK (160 - 16 bps)

% MODE DATA GENERATION RATES 
P.rate_Standby_kbps       = 1.38;
P.rate_Cruise_kbps        = 55.94;
P.rate_PreInsp_kbps       = 241.86;  % ONC-W imagery ON, LORRI+LWIR imagery OFF
P.rate_Approach_kbps      = 242.23;
P.rate_Inspection_kbps    = 694.50;  % All 3 cameras + all HK
P.rate_DL_bg_kbps         = 5.86;   % HK generated during downlink (cameras OFF)
P.rate_Safe_kbps          = 5.5;
P.rate_Conjunction_kbps   = 5.17;   % kbps 

% Background HK during Inspection 
P.insp_bg_kbps = P.rate_Inspection_kbps - sum(P.cam_rate_kbps) - P.la_sci_kbps;

% HK TOTAL 
P.hk_total_bps = 5888;  

% INSPECTION IMAGE BUDGET
%   ONC-W = 6 imgs/face, LORRI = 6 imgs/face, LWIR = 44 imgs/face
%   Total = 56 imgs/face -> 336 imgs per 6-face inspection cycle.
P.imgs_per_cam_per_face = [6; 6; 44];   % order matches P.cam_names
P.n_imgs_required       = sum(P.imgs_per_cam_per_face);  % legacy field
P.n_imgs_margin         = 0;                             % legacy field
P.n_imgs_planned        = sum(P.imgs_per_cam_per_face);  % legacy field

% FACE / ROTATION GEOMETRY 
P.n_faces            = 6;
P.face_angle_deg     = 90;     % deg (cube face geometry)
P.n_rotations        = P.n_faces - 1;  % 5 transitions
P.solo_rot_deg_s     = 0.15;   % deg/s 
P.rot_time_s         = P.face_angle_deg / P.solo_rot_deg_s;  % 600 s = 10 min
P.rot_time_min       = P.rot_time_s / 60;
P.rot_time_hr        = P.rot_time_s / 3600;

% Per-face operational margins
P.settle_min      = 3;   % pointing settle post-rotation
P.onboard_val_min = 2;   % onboard image validation
P.gnd_margin_min  = 15;  % ground-response reserve 
P.face_margin_min = P.settle_min + P.onboard_val_min + P.gnd_margin_min;  % 20 min

% ESTRACK CONTACT 
P.contact_hr  = 8.0;   % hr/day max 
P.period_hr   = 24.0;

% CONOPS 14-DAY TIMING 
P.win_dur_hr              = 14 * 24;
P.t_precond_hr            = 0.25;
P.t_arrive_hr             = 0.25;
P.t_preinsp_start_hr      = 0.50;
P.n_cal_images            = 40;     
P.t_prelim_dl_hr          = 24.0;
P.t_soc_review_start_hr   = 48.0;
P.t_hitl_gate_hr          = 95.5;
P.t_insp_campaign_hr      = 96.0;
P.t_depart_start_hr       = 13 * 24;
P.t_depart_dur_hr         = 4.0;
P.t_seq_upload_hr         = 0.25;
P.insp_days               = 9;     

% SAFE MODE / NO-SUN BUDGET 
P.safe_fault_min  = 5;
P.safe_sun_min    = 60;
P.safe_margin_min = 55;
P.safe_noSun_hr   = (P.safe_fault_min + P.safe_sun_min + P.safe_margin_min) / 60;

% POWER MODES (W) 
P.pwr_standby_W = 44.3;
P.pwr_safe_W    = 118.5;
P.pwr_hga_tx_W  = 238.5;

% SSMM 
P.SSMM_cap_GB = 64;

% HOUSEKEEPING REFERENCE CASES 
P.hk_rate_kbps        = P.rate_Standby_kbps;
P.hk_far_range_AU     = 2.0;
P.hk_nom_range_AU     = 1.0;
P.hk_far_dl_kbps      = 12.20;   
P.hk_nom_dl_kbps      = 49.00;  
P.hk_contact_start_hr = 8.0;

% SOLAR CONJUNCTION (30-day worst case) 
P.conj_days        = 30;        % days (worst-case blackout duration)
P.conj_sep_deg     = 2.0;       % deg, Sun-Earth-Probe angle blackout threshold
P.conj_range_AU    = P.hk_far_range_AU;          % 2.0 AU 
P.conj_range_km    = P.conj_range_AU * AU_km;
P.conj_gen_kbps    = P.rate_Conjunction_kbps;    % 5.17 kbps stored during blackout
P.conj_pre_dl_kbps = P.hk_far_dl_kbps;           % 12.20 kbps far-range entry pass
P.conj_rec_dl_kbps = P.hk_far_dl_kbps;           % 12.20 kbps worst-case recovery rate

% SUN-POINTING FLAGS 
P.sunpt_Standby     = true;
P.sunpt_Approach    = false;
P.sunpt_PreInsp     = false;
P.sunpt_Inspection  = false;
P.sunpt_Downlink    = true;
P.sunpt_Conjunction = true;     

% OFF-SUN ACCOUNTING ASSUMPTION
% false = downlink uses gimballed HGA while body/arrays stay Sun-favouring.
% true  = count the downlink contact as body off-Sun as well.
P.downlink_is_offSun = false;
end

function print_parameter_summary(P)
fprintf('INSPECTION GEOMETRY (CDR Data Budget Table 5):\n');
fprintf('  Insp 1: %.4f AU / %d km / %d kbps / 6.0 dB margin\n', ...
    P.insp1_range_AU, P.insp1_range_km, P.insp1_dl_kbps);
fprintf('  Insp 2: %.4f AU / %d km / %d kbps / 6.1 dB margin\n', ...
    P.insp2_range_AU, P.insp2_range_km, P.insp2_dl_kbps);
fprintf('\nCAMERAS (Table 4 rates + camera document image sizes):\n');
for i = 1:numel(P.cam_names)
    cadence = 1 / P.cam_op_fps(i);
    fprintf('  %-10s: %5.1f kbps, %.4f MB/img, %.5f fps (1 img / %.0f s)\n', ...
        P.cam_names{i}, P.cam_rate_kbps(i), P.cam_image_MB(i), ...
        P.cam_op_fps(i), cadence);
end
fprintf('\nMODE RATES (Table 4 totals):\n');
fprintf('  Standby=%.2f, Cruise=%.2f, Pre-Insp=%.2f, Approach=%.2f, Inspection=%.2f kbps\n', ...
    P.rate_Standby_kbps, P.rate_Cruise_kbps, P.rate_PreInsp_kbps, ...
    P.rate_Approach_kbps, P.rate_Inspection_kbps);
fprintf('  Safe=%.2f, Conjunction=%.2f kbps\n', P.rate_Safe_kbps, P.rate_Conjunction_kbps);
fprintf('\nHK total: %d bps (Table 3, includes Laser Altimeter)\n', P.hk_total_bps);
fprintf('Face angle: %.0f deg (cube). Rotation: %.0f s / %.1f min per face at %.2f deg/s\n', ...
    P.face_angle_deg, P.rot_time_s, P.rot_time_min, P.solo_rot_deg_s);
fprintf('Conjunction: %d-day blackout @ %.2f kbps | SEP threshold %.1f deg | %.1f AU geometry\n\n', ...
    P.conj_days, P.conj_gen_kbps, P.conj_sep_deg, P.conj_range_AU);
end

%  CASE DEFINITIONS

function C = define_inspection_cases(P)
C(1).name       = 'Inspection 1';
C(1).date       = P.insp1_date;
C(1).range_AU   = P.insp1_range_AU;
C(1).range_km   = P.insp1_range_km;
C(1).dl_kbps    = P.insp1_dl_kbps;

C(2).name       = 'Inspection 2';
C(2).date       = P.insp2_date;
C(2).range_AU   = P.insp2_range_AU;
C(2).range_km   = P.insp2_range_km;
C(2).dl_kbps    = P.insp2_dl_kbps;
end

function H = define_housekeeping_cases(P)
H(1).name             = 'HK Far (2.0 AU)';
H(1).date             = '2.0 AU';
H(1).range_AU         = P.hk_far_range_AU;
H(1).range_km         = P.hk_far_range_AU * 149597870.7;
H(1).dl_kbps          = P.hk_far_dl_kbps;
H(1).generate_kbps    = P.hk_rate_kbps;
H(1).contact_start_hr = P.hk_contact_start_hr;
H(1).contact_hr       = P.contact_hr;

H(2).name             = 'HK Nominal (1.0 AU)';
H(2).date             = '1.0 AU';
H(2).range_AU         = P.hk_nom_range_AU;
H(2).range_km         = P.hk_nom_range_AU * 149597870.7;
H(2).dl_kbps          = P.hk_nom_dl_kbps;
H(2).generate_kbps    = P.hk_rate_kbps;
H(2).contact_start_hr = P.hk_contact_start_hr;
H(2).contact_hr       = P.contact_hr;
end

function X = define_conjunction_cases(P)
% 30-day worst-case superior solar conjunction (comms blackout).
X(1).name        = 'Solar Conjunction';
X(1).date        = sprintf('%d-day worst case', P.conj_days);
X(1).range_AU    = P.conj_range_AU;
X(1).range_km    = P.conj_range_km;
X(1).dl_kbps     = 0;                 % no downlink while in blackout
X(1).gen_kbps    = P.conj_gen_kbps;   % Conjunction-mode HK rate (stored)
X(1).conj_days   = P.conj_days;
X(1).pre_dl_kbps = P.conj_pre_dl_kbps;
X(1).rec_dl_kbps = P.conj_rec_dl_kbps;
end

%  IMAGING PLAN 
function Plan = compute_imaging_plan(P, C)
Plan = struct();

% per-camera image plan
Plan.n_imgs_per_cam_per_face = P.imgs_per_cam_per_face;          % [6; 6; 44]
Plan.n_imgs_per_face         = sum(P.imgs_per_cam_per_face);     % 56
Plan.n_imgs_required         = Plan.n_imgs_per_face;             % legacy table field
Plan.n_imgs_margin           = 0;                                % legacy table field

% Operational cadence 
Plan.cam_op_fps              = P.cam_op_fps;
Plan.cam_cadence_s           = P.cam_cadence_s;

% Imaging time per face assumes the planned images are acquired sequentially
Plan.imaging_min_per_face    = sum(P.imgs_per_cam_per_face .* P.cam_cadence_s) / 60;

% Face slot = imaging + settle/onboard-validation/ground-response margin.
Plan.face_margin_min         = P.face_margin_min;
Plan.face_slot_min           = Plan.imaging_min_per_face + Plan.face_margin_min;

% Data per face and per cycle.
Plan.img_MB_per_cam_per_face = P.imgs_per_cam_per_face .* P.cam_image_MB;
Plan.img_MB_per_face         = sum(Plan.img_MB_per_cam_per_face);
Plan.img_MB_per_cycle        = Plan.img_MB_per_face * P.n_faces;
Plan.total_imgs_per_cycle    = Plan.n_imgs_per_face * P.n_faces;

% Timing.
Plan.imaging_hr              = P.n_faces * Plan.imaging_min_per_face / 60;
Plan.margin_hr               = P.n_faces * P.face_margin_min / 60;
Plan.rotation_hr             = P.n_rotations * P.rot_time_hr;
Plan.cycle_hr                = Plan.imaging_hr + Plan.margin_hr + Plan.rotation_hr;

% Total data per cycle: camera data + background HK during imaging/margins/rotations.
Plan.bg_imaging_MB           = kbps_hr_to_MB(P.insp_bg_kbps, Plan.imaging_hr);
Plan.bg_margin_MB            = kbps_hr_to_MB(P.insp_bg_kbps, Plan.margin_hr);
Plan.bg_rotation_MB          = kbps_hr_to_MB(P.insp_bg_kbps, Plan.rotation_hr);
Plan.total_cycle_MB          = Plan.img_MB_per_cycle + Plan.bg_imaging_MB + ...
                               Plan.bg_margin_MB + Plan.bg_rotation_MB;

% Contact window verification.
Plan.dl_cap_MB               = kbps_hr_to_MB(C.dl_kbps, P.contact_hr);
Plan.contacts_per_cycle      = ceil(Plan.total_cycle_MB / Plan.dl_cap_MB);
Plan.daily_backlog_MB        = Plan.total_cycle_MB - Plan.dl_cap_MB;

% Light time.
Plan.owlt_min                = C.range_km / 299792.458 / 60;
Plan.rtlt_min                = 2 * Plan.owlt_min;

% Conservative off-Sun/no-Sun per cycle:
% body-fixed cameras point the spacecraft at the target during imaging,
% rotations, and margins.
Plan.noSun_hr                = Plan.cycle_hr;

% Pre-inspection calibration (ONC-W only, Pre-Insp mode).
Plan.cal_MB                  = P.n_cal_images * P.cam_image_MB(1);
Plan.cal_hr                  = MB_to_hr(Plan.cal_MB, P.rate_PreInsp_kbps);
end

function T = build_image_plan_table(P, C, Plan)
ncam = numel(P.cam_names);
T = table( ...
    repmat({C.name},ncam,1), repmat({C.date},ncam,1), ...
    repmat(C.range_AU,ncam,1), repmat(C.dl_kbps,ncam,1), ...
    P.cam_names, P.cam_rate_kbps, P.cam_image_MB, ...
    Plan.cam_op_fps, ...
    repmat(Plan.n_imgs_required,ncam,1), ...
    repmat(Plan.n_imgs_margin,ncam,1), ...
    Plan.n_imgs_per_cam_per_face, ...
    Plan.img_MB_per_cam_per_face, ...
    repmat(Plan.imaging_min_per_face,ncam,1), ...
    repmat(Plan.face_margin_min,ncam,1), ...
    repmat(Plan.face_slot_min,ncam,1), ...
    repmat(Plan.total_imgs_per_cycle,ncam,1), ...
    repmat(Plan.img_MB_per_cycle,ncam,1), ...
    repmat(Plan.total_cycle_MB,ncam,1), ...
    repmat(Plan.dl_cap_MB,ncam,1), ...
    repmat(Plan.contacts_per_cycle,ncam,1), ...
    repmat(Plan.daily_backlog_MB,ncam,1), ...
    repmat(Plan.rtlt_min,ncam,1), ...
    repmat(Plan.noSun_hr,ncam,1), ...
    'VariableNames', { ...
    'Case','Date','Range_AU','DL_kbps', ...
    'Camera','CamRate_kbps','ImageSize_MB','OpFps', ...
    'ImgsRequired_perFace','ImgsMargin_perFace','ImgsPerCamPerFace', ...
    'CamData_MB_perFace', ...
    'ImagingTime_min_perFace','OpMargin_min_perFace','FaceSlot_min', ...
    'TotalImages_perCycle','CameraData_MB_perCycle','TotalData_MB_perCycle', ...
    'DL8hr_Cap_MB','ContactsNeeded_perCycle','DailyBacklog_MB', ...
    'RTLT_min','ConservativeNoSun_hr'} );
end

%  TIMELINE BUILDERS

function T = build_inspection_day_24hr(P, C, Plan)
T = empty_tl(); t = 0;

T = add_seg(T,'Upload pre-validated sequence','Downlink', ...
    t, t+P.t_seq_upload_hr, P.sunpt_Downlink, P.rate_DL_bg_kbps, 0, 0, NaN, ...
    'HITL GO. Ground arms autonomous 6-face inspection sequence.');
t = t + P.t_seq_upload_hr;

[T,t] = add_6face_inspection(P, T, t, Plan, '24hr');

t_dl_end = min(t + P.contact_hr, 24);
T = add_seg(T,'Downlink inspection data + ground monitor','Downlink', ...
    t, t_dl_end, P.sunpt_Downlink, P.rate_DL_bg_kbps, C.dl_kbps, 0, NaN, ...
    sprintf('8-hr ESTRACK pass at %.0f kbps. Cameras OFF; only HK generated during DL.', ...
    C.dl_kbps));
t = t_dl_end;

if t < 24
    T = add_seg(T,'Standby / store remaining backlog','Standby', ...
        t, 24, P.sunpt_Standby, P.rate_Standby_kbps, 0, 0, NaN, ...
        sprintf('%.1f MB backlog from this cycle carried to next pass.', ...
        Plan.daily_backlog_MB));
end
end

function T = build_inspection_window_14day(P, C, Plan)
T = empty_tl(); t = 0;

% Window preconditions
T = add_seg(T,'Window preconditions: SEP + ESTRACK check','Standby', ...
    t, t+P.t_precond_hr, P.sunpt_Standby, P.rate_Standby_kbps,0,0,NaN, ...
    'Verify SEP angle >5 deg and ESTRACK contact available.');
t = t + P.t_precond_hr;

% Arrive at inspection geometry
T = add_seg(T,'Arrive at inspection geometry (20 km to 250 m)','Approach', ...
    t, t+P.t_arrive_hr, P.sunpt_Approach, P.rate_Approach_kbps,0,0,NaN, ...
    'Close from 20 km to 250 m standoff. Approach mode: 241.68 kbps (Table 4).');
t = t + P.t_arrive_hr;

T = add_standby_gap(P, T, t, P.t_preinsp_start_hr, 'Standby gap before Day 1 pre-inspection');

% Day 1 — pre-inspection check (ONC-W only, Pre-Insp mode)
T = add_seg(T,'Pre-inspection check: 40 ONC-W calibration images','Pre-Inspection', ...
    P.t_preinsp_start_hr, P.t_preinsp_start_hr + Plan.cal_hr, ...
    P.sunpt_PreInsp, P.rate_PreInsp_kbps, 0, P.n_cal_images, Plan.cal_MB, ...
    sprintf('Day 1: 40 ONC-W images across settings. LORRI+LWIR imagery OFF. Rate=%.2f kbps (Table 4).', ...
    P.rate_PreInsp_kbps));
t = P.t_preinsp_start_hr + Plan.cal_hr;

T = add_standby_gap(P, T, t, P.t_prelim_dl_hr, 'Standby gap before Day 2 downlink');

% Day 2 — preliminary downlink
T = add_seg(T,'Downlink preliminary data + HK','Downlink', ...
    P.t_prelim_dl_hr, P.t_prelim_dl_hr + P.contact_hr, ...
    P.sunpt_Downlink, P.rate_DL_bg_kbps, C.dl_kbps, 0, NaN, ...
    'Day 2: 8-hr ESTRACK pass. Downlink cal images and HK.');
t = P.t_prelim_dl_hr + P.contact_hr;

T = add_standby_gap(P, T, t, P.t_soc_review_start_hr, 'Standby before SOC review');

% Day 3-4 — SOC review + HITL gate
T = add_seg(T,'SOC ground review: camera, geometry, S/C health','Standby', ...
    P.t_soc_review_start_hr, P.t_hitl_gate_hr, ...
    P.sunpt_Standby, P.rate_Standby_kbps, 0, 0, NaN, ...
    'Day 3-4: Review calibration images and spacecraft health. MOC turnaround <4 hr per SSR-MC-03.');
T = add_seg(T,'HITL gate: GO / NO-GO','Standby', ...
    P.t_hitl_gate_hr, P.t_insp_campaign_hr, ...
    P.sunpt_Standby, P.rate_Standby_kbps, 0, 0, NaN, ...
    'Nominal: GO. NO-GO -> Problem Mode ~6 days (contingency, not in nominal timeline).');

% Day 5-13 — repeated daily inspection cycles
cycNum = 1;
tDay   = P.t_insp_campaign_hr;
while tDay < P.t_depart_start_hr
    T = add_standby_gap(P, T, T.End_hr(end), tDay, ...
        sprintf('Standby before cycle %d', cycNum));
    t = tDay;

    T = add_seg(T, sprintf('Cycle %d: upload sequence', cycNum), 'Downlink', ...
        t, t+P.t_seq_upload_hr, P.sunpt_Downlink, P.rate_DL_bg_kbps, 0, 0, NaN, ...
        sprintf('Day %.0f: arm inspection cycle %d.', floor(t/24)+1, cycNum));
    t = t + P.t_seq_upload_hr;

    [T,t] = add_6face_inspection(P, T, t, Plan, sprintf('C%d', cycNum));

    t_dl_end = min(t + P.contact_hr, P.t_depart_start_hr);
    T = add_seg(T, sprintf('Cycle %d: downlink + ground monitor', cycNum), 'Downlink', ...
        t, t_dl_end, P.sunpt_Downlink, P.rate_DL_bg_kbps, C.dl_kbps, 0, NaN, ...
        sprintf('8-hr ESTRACK pass. Cameras OFF during DL. Daily backlog: %.1f MB.', ...
        Plan.daily_backlog_MB));

    cycNum = cycNum + 1;
    tDay   = tDay + 24;
end

T = add_standby_gap(P, T, T.End_hr(end), P.t_depart_start_hr, 'Standby before Day 14 depart');

% Day 14 — depart
T = add_seg(T,'Depart inspection geometry: window complete','Approach', ...
    P.t_depart_start_hr, ...
    min(P.t_depart_start_hr + P.t_depart_dur_hr, P.win_dur_hr), ...
    P.sunpt_Approach, P.rate_Approach_kbps, 0, 0, NaN, ...
    'Day 14: depart inspection geometry.');
T = add_standby_gap(P, T, T.End_hr(end), P.win_dur_hr, 'Standby after depart to end of window');
end

function [T, t] = add_6face_inspection(P, T, t, Plan, label)
% 6-face inspection: all 3 cameras ON (ONC-W + LORRI + LWIR)
% Data rate = P.rate_Inspection_kbps during imaging
% Background HK = P.insp_bg_kbps during margins and rotations

for f = 1:P.n_faces
    % Imaging phase: all 3 cameras ---
    total_imgs = sum(Plan.n_imgs_per_cam_per_face);
    T = add_seg(T, sprintf('%s Face %d imaging (ONC-W+LORRI+LWIR, %d imgs)', label, f, total_imgs), ...
        'Inspection', t, t + Plan.imaging_min_per_face/60, ...
        P.sunpt_Inspection, P.rate_Inspection_kbps, 0, total_imgs, Plan.img_MB_per_face, ...
        sprintf('ONC-W=%d, LORRI=%d, LWIR=%d images. Rate=%.2f kbps (Table 4 Inspection total).', ...
        Plan.n_imgs_per_cam_per_face(1), Plan.n_imgs_per_cam_per_face(2), Plan.n_imgs_per_cam_per_face(3), P.rate_Inspection_kbps));
    t = t + Plan.imaging_min_per_face/60;

    % Margin phase: cameras OFF, background HK only ---
    T = add_seg(T, sprintf('%s Face %d margin (%d+%d+%d min)', label, f, ...
        P.settle_min, P.onboard_val_min, P.gnd_margin_min), ...
        'Inspection', t, t + P.face_margin_min/60, ...
        P.sunpt_Inspection, P.insp_bg_kbps, 0, 0, NaN, ...
        sprintf('Cameras OFF. %d min settle + %d min onboard val + %d min gnd reserve.', ...
        P.settle_min, P.onboard_val_min, P.gnd_margin_min));
    t = t + P.face_margin_min/60;

    % Rotation to next face 
    if f < P.n_faces
        T = add_seg(T, sprintf('%s rotate to face %d (90 deg / 0.15 deg/s = %.0f s)', ...
            label, f+1, P.rot_time_s), 'Inspection', ...
            t, t + P.rot_time_hr, ...
            P.sunpt_Inspection, P.insp_bg_kbps, 0, 0, NaN, ...
            'Cube face transition: 90 deg at 0.15 deg/s = 600 s = 10 min. Cameras OFF during rotation.');
        t = t + P.rot_time_hr;
    end
end
end

function T = build_housekeeping_24hr(P, H)
T = empty_tl();
T = add_seg(T,'HK store before contact','Standby', ...
    0, H.contact_start_hr, P.sunpt_Standby, H.generate_kbps, 0, 0, NaN, ...
    sprintf('HK stored at %.2f kbps (Standby mode, Table 4). No downlink.', H.generate_kbps));
T = add_seg(T,'HK downlink contact','Downlink', ...
    H.contact_start_hr, H.contact_start_hr + H.contact_hr, ...
    P.sunpt_Downlink, H.generate_kbps, H.dl_kbps, 0, NaN, ...
    sprintf('8-hr HGA contact. DL: %.2f kbps (Table 5, %.1f AU case).', H.dl_kbps, H.range_AU));
T = add_seg(T,'HK store after contact','Standby', ...
    H.contact_start_hr + H.contact_hr, 24, ...
    P.sunpt_Standby, H.generate_kbps, 0, 0, NaN, ...
    'HK stored at Standby rate. Backlog (if any) carries to next pass.');
end

function T = build_conjunction_window(P, X)
% 30-day worst-case solar conjunction.
%   Day 0   : final pre-conjunction downlink (empty the SSMM), then configure.
%   Day 1-30: comms blackout. Conjunction-mode HK stored to SSMM. Sun-pointed.
%   Day 31  : first recovery pass at far-range rate (contact re-established).
% Full backlog clear-out is reported analytically in print_conjunction_case,
% because the post-conjunction downlink rate climbs as the range closes and a
% fixed-rate ramp would misrepresent the recovery profile.
T = empty_tl(); t = 0;

% Day 0 — final pre-conjunction downlink to empty the SSMM before blackout
T = add_seg(T,'Pre-conjunction downlink: clear SSMM','Downlink', ...
    t, t + P.contact_hr, P.sunpt_Downlink, P.rate_DL_bg_kbps, X.pre_dl_kbps, 0, NaN, ...
    sprintf('Final %.0f-hr ESTRACK pass before SEP drops below %.1f deg. SSMM emptied at %.2f kbps.', ...
    P.contact_hr, P.conj_sep_deg, X.pre_dl_kbps));
t = t + P.contact_hr;

% Remainder of Day 0 — slew to Sun-point, arm autonomous safe ops
T = add_seg(T,'Configure for conjunction (Sun-pointed)','Standby', ...
    t, 24, P.sunpt_Standby, P.rate_Standby_kbps, 0, 0, NaN, ...
    'Slew to Sun-point, autonomous fault management armed. No science, no proximity ops.');
t = 24;

% Day 1-30 — comms blackout: store Conjunction-mode HK
t_end = t + X.conj_days * 24;
T = add_seg(T, sprintf('Solar conjunction blackout (%d days)', X.conj_days), 'Conjunction', ...
    t, t_end, P.sunpt_Conjunction, X.gen_kbps, 0, 0, NaN, ...
    sprintf('SEP < %.1f deg: no uplink/downlink. HK stored at %.2f kbps. Sun-pointed, arrays illuminated.', ...
    P.conj_sep_deg, X.gen_kbps));
t = t_end;

% Day 31 — first recovery pass (far-range geometry, worst case)
T = add_seg(T,'Post-conjunction recovery pass 1 (far range)','Downlink', ...
    t, t + P.contact_hr, P.sunpt_Downlink, P.rate_DL_bg_kbps, X.rec_dl_kbps, 0, NaN, ...
    sprintf('SEP > %.1f deg: contact restored. Backlog dump begins at %.2f kbps (far-range worst case).', ...
    P.conj_sep_deg, X.rec_dl_kbps));
t = t + P.contact_hr;
end

%  FINALIZATION + SUMMARIES  (unchanged logic, cleaner output)

function T = finalize_timeline(T)
n = height(T);
ssmm = 0;
T.DL_Cap_MB     = zeros(n,1);
T.Actual_DL_MB  = zeros(n,1);
T.SSMM_Start_MB = zeros(n,1);
T.SSMM_End_MB   = zeros(n,1);
T.Net_Stored_MB = zeros(n,1);

for i = 1:n
    cap = kbps_hr_to_MB(T.DL_kbps(i), T.Duration_hr(i));
    T.SSMM_Start_MB(i) = ssmm;
    avail = ssmm + T.Gen_MB(i);
    dl    = min(avail, cap);
    ssmm  = avail - dl;
    T.DL_Cap_MB(i)    = cap;
    T.Actual_DL_MB(i) = dl;
    T.SSMM_End_MB(i)  = ssmm;
    T.Net_Stored_MB(i)= T.Gen_MB(i) - dl;
end
end

function S = summarize_timeline(C, scale, T)
S = table( ...
    {C.name},{C.date},{scale}, C.range_AU, C.dl_kbps, ...
    max(T.End_hr)-min(T.Start_hr), sum(T.PlannedImages), ...
    sum(T.Gen_MB), sum(T.Actual_DL_MB), T.SSMM_End_MB(end), max(T.SSMM_End_MB), ...
    sum(T.Duration_hr(~T.SunPointed)), max_contiguous_no_sun(T), ...
    sum(T.Duration_hr(strcmp(T.Mode,'Standby'))), ...
    sum(T.Duration_hr(strcmp(T.Mode,'Inspection'))), ...
    sum(T.Duration_hr(strcmp(T.Mode,'Downlink'))), ...
    sum(T.Duration_hr(strcmp(T.Mode,'Conjunction'))), ...
    'VariableNames',{'Case','Date','Scale','Range_AU','DL_kbps', ...
    'Duration_hr','TotalImages','Generated_MB','Downlinked_MB', ...
    'EndSSMM_MB','PeakSSMM_MB','NoSun_hr','MaxContNoSun_hr', ...
    'Standby_hr','Inspection_hr','Downlink_hr','Conjunction_hr'});
end

function v = max_contiguous_no_sun(T)
v=0; cur=0;
for i=1:height(T)
    if ~T.SunPointed(i), cur=cur+T.Duration_hr(i); v=max(v,cur);
    else, cur=0; end
end
end

function Ct = build_contact_summary(C, scale, T)
rows=find(T.DL_kbps>0);
CaseName={}; Date={}; Scale={}; Num=[]; Start_hr=[]; End_hr=[];
Dur_hr=[]; Rate_kbps=[]; Cap_MB=[]; DL_MB=[]; SSMMi=[]; SSMMf=[]; Util_pct=[];
for j=1:numel(rows)
    i=rows(j);
    CaseName{end+1,1}=C.name; Date{end+1,1}=C.date; Scale{end+1,1}=scale; %#ok<AGROW>
    Num(end+1,1)=j; Start_hr(end+1,1)=T.Start_hr(i); End_hr(end+1,1)=T.End_hr(i); %#ok<AGROW>
    Dur_hr(end+1,1)=T.Duration_hr(i); Rate_kbps(end+1,1)=T.DL_kbps(i); %#ok<AGROW>
    Cap_MB(end+1,1)=T.DL_Cap_MB(i); DL_MB(end+1,1)=T.Actual_DL_MB(i); %#ok<AGROW>
    SSMMi(end+1,1)=T.SSMM_Start_MB(i); SSMMf(end+1,1)=T.SSMM_End_MB(i); %#ok<AGROW>
    if T.DL_Cap_MB(i)>0, Util_pct(end+1,1)=100*T.Actual_DL_MB(i)/T.DL_Cap_MB(i); %#ok<AGROW>
    else, Util_pct(end+1,1)=0; end %#ok<AGROW>
end
Ct=table(CaseName,Date,Scale,Num,Start_hr,End_hr,Dur_hr,Rate_kbps, ...
    Cap_MB,DL_MB,SSMMi,SSMMf,Util_pct);
end

function D = build_daily_backlog(C, scale, T, nDays)
CaseName={}; Date={}; Scale={}; Day=[]; S_hr=[]; E_hr=[];
SSMMi=[]; Gen=[]; Cap=[]; DL=[]; SSMMf=[]; Carry=[]; Full=[];
ssmm=0;
for d=1:nDays
    ds=(d-1)*24; de=d*24;
    si=ssmm; gi=0; ci=0; di=0;
    for i=1:height(T)
        os=max(ds,T.Start_hr(i)); oe=min(de,T.End_hr(i)); ov=oe-os;
        if ov<=0, continue; end
        frac=ov/T.Duration_hr(i);
        gm=T.Gen_MB(i)*frac;
        cm=kbps_hr_to_MB(T.DL_kbps(i),ov);
        av=ssmm+gm; dm=min(av,cm); ssmm=av-dm;
        gi=gi+gm; ci=ci+cm; di=di+dm;
    end
    CaseName{end+1,1}=C.name; Date{end+1,1}=C.date; Scale{end+1,1}=scale; %#ok<AGROW>
    Day(end+1,1)=d; S_hr(end+1,1)=ds; E_hr(end+1,1)=de; %#ok<AGROW>
    SSMMi(end+1,1)=si; Gen(end+1,1)=gi; Cap(end+1,1)=ci; %#ok<AGROW>
    DL(end+1,1)=di; SSMMf(end+1,1)=ssmm; Carry(end+1,1)=ssmm; %#ok<AGROW>
    Full(end+1,1)=ssmm<=1e-6; %#ok<AGROW>
end
D=table(CaseName,Date,Scale,Day,S_hr,E_hr,SSMMi,Gen,Cap,DL,SSMMf,Carry,Full, ...
    'VariableNames',{'Case','Date','Scale','Day','Start_hr','End_hr', ...
    'SSMM_Start_MB','Generated_MB','DL_Cap_MB','Downlinked_MB','SSMM_End_MB', ...
    'Backlog_MB','FullyDumped'});
end

function I = build_seg_index(C, scale, T)
n=height(T);
I=table(repmat({C.name},n,1),repmat({C.date},n,1),repmat({scale},n,1), ...
    (1:n)',T.Segment,T.Mode,T.Start_hr,T.End_hr,T.Duration_hr, ...
    T.SunPointed,T.Gen_MB,T.Actual_DL_MB,T.SSMM_End_MB, ...
    'VariableNames',{'Case','Date','Scale','SegNum','Segment','Mode', ...
    'Start_hr','End_hr','Duration_hr','SunPointed','Gen_MB','DL_MB','SSMM_End_MB'});
end

%  ASSUMPTION TABLES

function T = build_conops_table(P)
Phase={
    'Window preconditions';'Arrive at geometry';
    'Pre-inspection check (Day 1)';'Preliminary downlink (Day 2)';
    'SOC review (Days 3-4)';'HITL gate';
    'Inspection campaigns (Days 5-13)';'Downlink per cycle';'Depart (Day 14)';
    'Solar conjunction (worst case)'};
Notes={
    'SEP angle and ESTRACK contact check.';
    sprintf('Close 20 km to 250 m. Approach mode: %.2f kbps. 5 x 90 deg rotations (cube).', P.rate_Approach_kbps);
    sprintf('40 ONC-W images. Pre-Insp mode: %.2f kbps. LORRI+LWIR imagery OFF.', P.rate_PreInsp_kbps);
    '8-hr ESTRACK pass.';
    'Camera, geometry, S/C health check. Turnaround <4 hr (SSR-MC-03).';
    'Nominal: GO. NO-GO -> Problem Mode ~6 days.';
    sprintf('Daily: upload + 6-face inspection. Inspection mode: %.2f kbps. 3 cameras ON simultaneously.', P.rate_Inspection_kbps);
    '8-hr ESTRACK pass at 85/89 kbps. Cameras OFF. Daily backlog accumulates.';
    'Window complete.';
    sprintf('%d-day comms blackout (SEP < %.1f deg). Conjunction mode %.2f kbps stored. Sun-pointed.', ...
        P.conj_days, P.conj_sep_deg, P.conj_gen_kbps)};
T=table(Phase,Notes);
end

function T = build_safe_mode_table(P)
Mode={'SAFE_ACQUIRE_NO_SUN';'SAFE_LGA_BEACON_SUN_POINTED'};
SunPointed={'NO';'YES'};
Dur_hr=[P.safe_noSun_hr; P.contact_hr];
FD=[P.safe_fault_min;0]; SA=[P.safe_sun_min;0]; Mg=[P.safe_margin_min;0];
Pwr=[P.pwr_safe_W;P.pwr_safe_W];
T=table(Mode,SunPointed,FD,SA,Mg,Dur_hr,Pwr,Pwr.*Dur_hr, ...
    'VariableNames',{'Mode','SunPointed','FaultDetect_min','SunAcq_min', ...
    'Margin_min','Duration_hr','CommsPower_W','CommsEnergy_Wh'});
end

%  PRINTING

function print_inspection_case(P, C, Plan, T24, T14)
S24=summarize_timeline(C,'24hr',T24);
S14=summarize_timeline(C,'14day',T14);
fprintf('\n--- %s | %s ---\n', C.name, C.date);
fprintf('Range: %.4f AU / %.0f Mkm | DL: %.0f kbps (Table 5)\n', ...
    C.range_AU, C.range_km/1e6, C.dl_kbps);
fprintf('OWLT: %.2f min | RTLT: %.2f min\n', Plan.owlt_min, Plan.rtlt_min);
fprintf('Cameras (3): ONC-W %.1f kbps | LORRI %.1f kbps | LWIR %.1f kbps (Table 4)\n', ...
    P.cam_rate_kbps(1), P.cam_rate_kbps(2), P.cam_rate_kbps(3));
fprintf('Cadence: ONC-W ~%.0f s | LORRI ~%.0f s | LWIR ~%.0f s (operational fps from Table 4)\n', ...
    P.cam_cadence_s(1), P.cam_cadence_s(2), P.cam_cadence_s(3));
fprintf('Images: %d+%d=%d planned/face | Imaging: %.1f min/face | Rotation: %.0f s (90 deg)\n', ...
    Plan.n_imgs_required, Plan.n_imgs_margin, Plan.n_imgs_per_face, ...
    Plan.imaging_min_per_face, P.rot_time_s);
fprintf('Cycle: %.2f hr (imaging %.2f + margin %.2f + rotation %.2f)\n', ...
    Plan.cycle_hr, Plan.imaging_hr, Plan.margin_hr, Plan.rotation_hr);
fprintf('Cycle data: %.1f MB imagery + %.1f MB HK = %.1f MB total\n', ...
    Plan.img_MB_per_cycle, Plan.bg_imaging_MB+Plan.bg_margin_MB+Plan.bg_rotation_MB, ...
    Plan.total_cycle_MB);
fprintf('8-hr DL cap: %.1f MB | Contacts needed/cycle: %d | Daily backlog: %.1f MB\n', ...
    Plan.dl_cap_MB, Plan.contacts_per_cycle, Plan.daily_backlog_MB);
fprintf('24-hr: Gen=%.1f MB, DL=%.1f MB, End-SSMM=%.1f MB, MaxNoSun=%.2f hr\n', ...
    S24.Generated_MB, S24.Downlinked_MB, S24.EndSSMM_MB, S24.MaxContNoSun_hr);
fprintf('14-day: Gen=%.1f MB, DL=%.1f MB, End-SSMM=%.1f MB, Images=%.0f\n', ...
    S14.Generated_MB, S14.Downlinked_MB, S14.EndSSMM_MB, S14.TotalImages);
end

function print_hk_case(H, T)
S=summarize_timeline(H,'HK 24hr',T);
fprintf('\n--- %s (Table 5) ---\n', H.name);
fprintf('Range: %.1f AU | HK gen: %.2f kbps | DL: %.2f kbps\n', ...
    H.range_AU, H.generate_kbps, H.dl_kbps);
fprintf('Gen=%.3f MB | DL=%.3f MB | End-SSMM=%.4f MB\n', ...
    S.Generated_MB, S.Downlinked_MB, S.EndSSMM_MB);
end

function print_conjunction_case(P, X, T)
S = summarize_timeline(X,'Conjunction 30 day',T);
peakMB = S.PeakSSMM_MB;
peakGB = peakMB/1000;
pct    = 100*peakGB/P.SSMM_cap_GB;

% Recovery sensitivity (raw backlog dump, ignoring ongoing HK generation)
cap_far = kbps_hr_to_MB(X.rec_dl_kbps,   P.contact_hr);   % far-range 12.2 kbps pass
cap_nom = kbps_hr_to_MB(P.hk_nom_dl_kbps, P.contact_hr);   % nominal 49 kbps pass
passes_far = ceil(peakMB / cap_far);
passes_nom = ceil(peakMB / cap_nom);

% Net clearance accounting for ongoing HK (Standby between passes, DL-bg in pass)
gen_pass = kbps_hr_to_MB(P.rate_DL_bg_kbps,  P.contact_hr);
gen_sb   = kbps_hr_to_MB(P.rate_Standby_kbps, 24 - P.contact_hr);
net_far  = cap_far - gen_pass - gen_sb;
net_nom  = cap_nom - gen_pass - gen_sb;

fprintf('\n--- %s (%s) ---\n', X.name, X.date);
fprintf('Geometry: %.1f AU | SEP blackout threshold: %.1f deg | HK stored: %.2f kbps\n', ...
    X.range_AU, P.conj_sep_deg, X.gen_kbps);
fprintf('Blackout: %d days = %.0f hr of NO uplink/downlink. Sun-pointed, batteries charged.\n', ...
    X.conj_days, X.conj_days*24);
fprintf('Peak SSMM at end of blackout: %.1f MB (%.3f GB) = %.2f%% of %d GB capacity.\n', ...
    peakMB, peakGB, pct, P.SSMM_cap_GB);
fprintf('  --> STORAGE IS NOT THE LIMITER: %.1f GB of margin remains.\n', P.SSMM_cap_GB - peakGB);
fprintf('Recovery downlink (raw backlog dump, 8-hr passes):\n');
fprintf('  far range  %.2f kbps -> %.1f MB/pass -> %d passes\n', X.rec_dl_kbps, cap_far, passes_far);
fprintf('  nominal    %.2f kbps -> %.1f MB/pass -> %d passes\n', P.hk_nom_dl_kbps, cap_nom, passes_nom);
fprintf('Net daily clearance with ongoing HK (Standby between passes):\n');
fprintf('  far range  %.1f MB/day (%.1f days to clear)\n', net_far, peakMB/max(net_far,eps));
fprintf('  nominal    %.1f MB/day (%.1f days to clear)\n', net_nom, peakMB/max(net_nom,eps));
fprintf('  NOTE: real recovery rate climbs as range closes; far-range is the bounding worst case.\n');
end

%  PLOTS

function plot_inspection_24hr(P, C, Plan, T)
figure('Position',[50 50 1700 950],'Name',[C.name ' 24 hr']);
subplot(3,1,1); plot_mode_bar(T,24);
title(sprintf('%s — 24-hr Inspection Day | %s | %d kbps | %.4f AU', ...
    C.name, C.date, C.dl_kbps, C.range_AU));
xlabel('Time after HITL GO (hr)');
subplot(3,1,2); plot_data_bars(T);
title(sprintf('Data per segment | 3 cameras: ONC-W+LORRI+LWIR | %.1f MB/cycle total', ...
    Plan.total_cycle_MB));
subplot(3,1,3); plot_ssmm_curve(P,T,24);
title(sprintf('SSMM fill | %d imgs/cycle | %.1f MB imagery + %.1f MB HK | %.1f MB daily backlog', ...
    Plan.total_imgs_per_cycle, Plan.img_MB_per_cycle, ...
    Plan.bg_imaging_MB+Plan.bg_margin_MB+Plan.bg_rotation_MB, Plan.daily_backlog_MB));
xlabel('Time (hr)'); drawnow;
end

function plot_inspection_14day(P, C, Plan, T)
figure('Position',[50 50 1700 950],'Name',[C.name ' 14 day']);
subplot(3,1,1); plot_mode_bar(T,P.win_dur_hr);
title(sprintf('%s — 14-Day CONOPS Window | 3 cameras | face angle 90 deg | %.1f MB/cycle', ...
    C.name, Plan.total_cycle_MB));
xlabel('Time from window start (hr)');
subplot(3,1,2); plot_ssmm_curve(P,T,P.win_dur_hr);
title(sprintf('14-day SSMM fill | Backlog %.1f MB/day (8-hr DL cap %.1f MB vs %.1f MB/cycle)', ...
    Plan.daily_backlog_MB, Plan.dl_cap_MB, Plan.total_cycle_MB));
xlabel('Time (hr)');
subplot(3,1,3); plot_cumulative_data(T,P.win_dur_hr);
title('Cumulative generated vs downlinked'); xlabel('Time (hr)'); drawnow;
end

function plot_hk_24hr(P, H, T)
figure('Position',[50 50 1650 900],'Name',H.name);
subplot(3,1,1); plot_mode_bar(T,24);
title(sprintf('%s | %.1f AU | %.2f kbps DL (Table 5)',H.name,H.range_AU,H.dl_kbps));
xlabel('Time (hr)');
subplot(3,1,2); plot_data_bars(T); title('HK data and contact capacity');
subplot(3,1,3); plot_ssmm_curve(P,T,24); title('HK SSMM fill'); xlabel('Time (hr)');
drawnow;
end

function plot_conjunction(P, X, T)
xEnd = max(T.End_hr);
peakMB = max(T.SSMM_End_MB);
figure('Position',[50 50 1700 850],'Name',X.name);
subplot(2,1,1); plot_mode_bar(T,xEnd);
title(sprintf('%s — %d-Day Comms Blackout | SEP < %.1f deg | %.1f AU | HK %.2f kbps', ...
    X.name, X.conj_days, P.conj_sep_deg, X.range_AU, X.gen_kbps));
xlabel('Time from conjunction entry (hr)');
subplot(2,1,2); plot_ssmm_curve(P,T,xEnd);
title(sprintf('SSMM fill | Peak %.1f MB (%.3f GB) = %.2f%% of %d GB | storage NOT the limiter', ...
    peakMB, peakMB/1000, 100*(peakMB/1000)/P.SSMM_cap_GB, P.SSMM_cap_GB));
xlabel('Time (hr)'); drawnow;
end

function plot_summary_bar(S)
figure('Position',[50 50 1600 650],'Name','Data Volume Summary');
labels=strcat(S.Case,{' — '},S.Scale);
x=categorical(labels); x=reordercats(x,labels);
bar(x,[S.Generated_MB, S.Downlinked_MB, S.EndSSMM_MB]);
ylabel('MB'); title('Data Volume Summary (CDR Data Budget — 3 cameras + conjunction)');
legend({'Generated','Downlinked','End-SSMM backlog'},'Location','best');
grid on; xtickangle(30); drawnow;
end

function plot_no_sun_bar(S, safeT)
figure('Position',[50 50 1450 600],'Name','No-Sun Summary');
idx=strcmp(S.Scale,'Inspection 24 hr');
labs=S.Case(idx); vals=S.MaxContNoSun_hr(idx);
labs=[labs;{'Safe Mode'}]; vals=[vals;safeT.Duration_hr(1)];
x=categorical(labs); x=reordercats(x,labs);
bar(x,vals); ylabel('Max continuous no-Sun (hr)');
title('Power Budget: Conservative No-Sun Duration (CDR)'); grid on;
for i=1:numel(vals)
    text(i,vals(i),sprintf(' %.2f hr',vals(i)),'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom','FontWeight','bold');
end
drawnow;
end

function plot_daily_backlog(D)
if isempty(D), return; end
figure('Position',[50 50 1400 600],'Name','Daily SSMM Backlog');
hold on;
for name=unique(D.Case,'stable')'
    idx=strcmp(D.Case,name{1});
    plot(D.Day(idx),D.SSMM_End_MB(idx)/1000,'-o','LineWidth',1.8,'DisplayName',name{1});
end
xlabel('Inspection window day'); ylabel('End-of-day SSMM backlog (GB)');
title('Daily SSMM Backlog | 3-camera payload (8-hr ESTRACK pass capacity: 306-320 MB)');
legend('Location','best'); grid on;
yline(64,'--k','SSMM 64 GB','LabelHorizontalAlignment','right'); drawnow;
end

function plot_mode_bar(T, xEnd)
hold on;
modeOrder={'Standby','Approach','Pre-Inspection','Inspection','Downlink','Safe','Conjunction'};
hNoSun=patch(nan,nan,[1.0 0.82 0.82],'EdgeColor','none','FaceAlpha',0.45,'DisplayName','No-Sun');
for i=1:height(T)
    if ~T.SunPointed(i)
        patch([T.Start_hr(i) T.End_hr(i) T.End_hr(i) T.Start_hr(i)],[0 0 1 1], ...
            [1.0 0.82 0.82],'EdgeColor','none','FaceAlpha',0.45,'HandleVisibility','off');
    end
end
hM=gobjects(numel(modeOrder),1);
for m=1:numel(modeOrder)
    hM(m)=patch(nan,nan,mode_color(modeOrder{m}),'EdgeColor','k','LineWidth',0.3, ...
        'DisplayName',modeOrder{m});
end
for i=1:height(T)
    patch([T.Start_hr(i) T.End_hr(i) T.End_hr(i) T.Start_hr(i)],[0.2 0.2 0.8 0.8], ...
        mode_color(T.Mode{i}),'EdgeColor','k','LineWidth',0.3,'HandleVisibility','off');
end
if xEnd<=24
    xticks(0:2:xEnd); min_sp=0.3; last=-inf;
    for i=1:height(T)
        xm=0.5*(T.Start_hr(i)+T.End_hr(i));
        if xm-last<min_sp, continue; end
        text(xm,0.9,sprintf('%d',i),'HorizontalAlignment','center','FontSize',8, ...
            'FontWeight','bold','BackgroundColor','w','Margin',1,'Clipping','on');
        last=xm;
    end
    text(0.01*xEnd,1.05,'Seg numbers -> Table_07_Segment_Index.csv','FontSize',8,'FontWeight','bold');
else
    for d=0:ceil(xEnd/24)
        if d*24<=xEnd
            xline(d*24,':',sprintf('D%d',d+1),'LabelVerticalAlignment','bottom', ...
                'FontSize',8,'HandleVisibility','off');
        end
    end
    xticks(0:24:xEnd);
end
xlim([0 xEnd]); ylim([0 1.15]); set(gca,'YTick',[]); grid on; box on;
legend([hM(:);hNoSun],'Location','eastoutside','FontSize',8);
end

function plot_data_bars(T)
n=height(T); y=1:n;
barh(y,[T.Gen_MB, T.DL_Cap_MB, T.Actual_DL_MB],'grouped');
xlabel('MB'); ylabel('Segment #');
legend({'Generated','DL capacity','Actual DL'},'Location','eastoutside');
grid on; set(gca,'YDir','reverse'); yticks(y); yticklabels(compose('%d',y));
xM=max([T.Gen_MB;T.DL_Cap_MB;T.Actual_DL_MB]); if xM<=0, xM=1; end
for i=1:n
    text(1.02*xM,i,T.Mode{i}(1:min(end,12)),'VerticalAlignment','middle','FontSize',7,'Clipping','off');
end
end

function plot_ssmm_curve(P, T, xEnd)
t=[]; s=[];
for i=1:height(T)
    t=[t;T.Start_hr(i);T.End_hr(i)]; s=[s;T.SSMM_Start_MB(i);T.SSMM_End_MB(i)]; %#ok<AGROW>
end
plot(t,s/1000,'LineWidth',1.8); hold on;
yline(P.SSMM_cap_GB,'--',sprintf('SSMM %d GB',P.SSMM_cap_GB));
ylabel('SSMM fill (GB)'); xlim([0 xEnd]); grid on;
end

function plot_cumulative_data(T, xEnd)
plot(T.End_hr,cumsum(T.Gen_MB),'LineWidth',1.8); hold on;
plot(T.End_hr,cumsum(T.Actual_DL_MB),'LineWidth',1.8);
ylabel('Cumulative (MB)'); legend({'Generated','Downlinked'},'Location','best');
xlim([0 xEnd]); grid on;
end

%% ========================================================================
%  LOW-LEVEL HELPERS
%% ========================================================================

function T = empty_tl()
T=table(cell(0,1),cell(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
    false(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),cell(0,1), ...
    'VariableNames',{'Segment','Mode','Start_hr','End_hr','Duration_hr', ...
    'SunPointed','Gen_kbps','DL_kbps','PlannedImages','Gen_MB','Notes'});
end

function T = add_seg(T,seg,mode,s,e,sun,gkbps,dkbps,imgs,gMB,notes)
dur=e-s; if dur<=0, return; end
if isnan(gMB), gMB=kbps_hr_to_MB(gkbps,dur); end
T=[T;table({seg},{mode},s,e,dur,logical(sun),gkbps,dkbps,imgs,gMB,{notes}, ...
    'VariableNames',T.Properties.VariableNames)];
end

function T = add_standby_gap(P,T,s,e,notes)
if e>s
    T=add_seg(T,notes,'Standby',s,e,P.sunpt_Standby,P.rate_Standby_kbps,0,0,NaN,notes);
end
end

function T = add_case_cols(C,scale,Tin)
% Note: column renamed Case_DL_kbps to avoid clash with per-segment DL_kbps in Tin
n=height(Tin);
T=[table(repmat({C.name},n,1),repmat({C.date},n,1),repmat({scale},n,1), ...
    repmat(C.range_AU,n,1),repmat(C.dl_kbps,n,1), ...
    'VariableNames',{'Case','Date','Scale','Range_AU','Case_DL_kbps'}),Tin];
end

function MB = kbps_hr_to_MB(kbps,hr)
MB=kbps*1e3*hr*3600/8e6;
end

function hr = MB_to_hr(MB,kbps)
hr=MB*8e6/(kbps*1e3)/3600;
end

function c = mode_color(m)
switch m
    case 'Standby',        c=[0.70 0.70 0.70];
    case 'Cruise',         c=[0.55 0.65 0.80];
    case 'Approach',       c=[0.85 0.55 0.25];
    case 'Pre-Inspection', c=[0.95 0.75 0.30];
    case 'Inspection',     c=[0.25 0.75 0.35];
    case 'Downlink',       c=[0.25 0.55 0.95];
    case 'Safe',           c=[0.90 0.35 0.30];
    case 'Conjunction',    c=[0.55 0.40 0.70];
    otherwise,             c=[0.60 0.60 0.60];
end
end

%  DUTY CYCLE (separate standalone PNG)
function plot_duty_cycle_figure(P, Plan)
figure('Color','w','Position',[80 90 1180 590],'Name','ODIN Duty Cycle');

% Pull timing from the same Plan used for data-volume/contact analysis.
cmd_hr     = P.t_seq_upload_hr;       % sequence upload / command arm
cycle_hr   = Plan.cycle_hr;           % imaging + margins + rotations
contact_hr = P.contact_hr;            % ESTRACK daily contact window
standby_hr = P.period_hr - cmd_hr - cycle_hr - contact_hr;

if standby_hr < -1e-9
    warning('Duty-cycle segments exceed one 24-hr day by %.2f hr.', -standby_hr);
end
standby_hr = max(0, standby_hr);

% (a) 24-hr macro timeline 
ax1 = subplot(2,1,1); hold(ax1,'on');

segs = [cmd_hr, cycle_hr, contact_hr, standby_hr];
cols = [0.38 0.55 0.78;   % command/upload
        0.85 0.33 0.30;   % inspection/off-Sun
        0.27 0.62 0.42;   % downlink
        0.72 0.74 0.78];  % standby
txtc = [1 1 1; 1 1 1; 1 1 1; 0 0 0];
labs = {sprintf('Seq. upload\n%.2f h',cmd_hr), ...
        sprintf('Inspection / target-pointing\n%.2f h',cycle_hr), ...
        sprintf('Downlink / ground monitor\n%.2f h',contact_hr), ...
        sprintf('Standby / Sun-pointing\n%.2f h',standby_hr)};

x0 = 0;
for k = 1:numel(segs)
    rectangle('Position',[x0 0 segs(k) 1],'FaceColor',cols(k,:), ...
        'EdgeColor','w','LineWidth',1.5,'Parent',ax1);
    if segs(k) >= 0.8
        fs = 9;
    else
        fs = 7.5;
    end
    text(x0+segs(k)/2,0.5,labs{k},'Parent',ax1,'Color',txtc(k,:), ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'FontSize',fs,'FontWeight','bold');
    x0 = x0 + segs(k);
end

xlim(ax1,[0 P.period_hr]); ylim(ax1,[0 1]);
set(ax1,'YTick',[],'XTick',0:2:P.period_hr);
xlabel(ax1,'Elapsed time in one inspection day (hours)  [order illustrative]');
title(ax1,'24-hr inspection day partitioned by operating mode');
box(ax1,'on');

% (b) duty fraction by activity 
ax2 = subplot(2,1,2);
duty_hr = [cmd_hr, Plan.imaging_hr, Plan.rotation_hr, Plan.margin_hr, contact_hr, standby_hr];
duty    = duty_hr / P.period_hr * 100;
labels  = {'Seq. upload','Imaging','Rotation','Margin/valid.','Downlink','Standby'};
dcols   = [0.38 0.55 0.78; 0.20 0.45 0.80; 0.95 0.60 0.20; ...
           0.65 0.78 0.92; 0.27 0.62 0.42; 0.72 0.74 0.78];

hb = bar(ax2, duty, 0.6, 'FaceColor','flat');
hb.CData = dcols;
set(ax2,'XTick',1:numel(labels),'XTickLabel',labels);
ylabel(ax2,'% of 24-hr day');
title(ax2,'Duty fraction by activity');
grid(ax2,'on');
ylim(ax2,[0 max(duty)+10]);

for i = 1:numel(duty)
    text(i, duty(i)+1.2, sprintf('%.1f%%\n%.2f h', duty(i), duty_hr(i)), ...
        'HorizontalAlignment','center','FontSize',8);
end

text(3, max(duty)+7, sprintf('Imaging + Rotation + Margin = inspection/off-Sun = %.2f h (%.1f%%)', ...
    cycle_hr, cycle_hr/P.period_hr*100), ...
    'HorizontalAlignment','center','FontSize',8.5,'FontAngle','italic', ...
    'Color',[0.55 0.15 0.12]);

sgtitle('ODIN  |  Inspection-Day Duty Cycle','FontWeight','bold','FontSize',13);

if exist('exportgraphics','file')
    exportgraphics(gcf,'Fig_ODIN_Duty_Cycle.png','Resolution',300);
    exportgraphics(gcf,'Fig_ODIN_Duty_Cycle.pdf');
end
drawnow;
end

% OFF-SUN / SUN-AVOIDANCE DURATION 
function plot_off_sun_figure(P, Plan)
figure('Color','w','Position',[80 90 1180 610],'Name','ODIN Off-Sun Duration');

imc  = [0.20 0.45 0.80];   % imaging
marc = [0.65 0.78 0.92];   % margin
rotc = [0.95 0.60 0.20];   % rotation

% (a) contiguous off-Sun interval expanded by face 
ax1 = subplot(2,1,1); hold(ax1,'on');

x0 = 0;
for f = 1:P.n_faces
    rectangle('Position',[x0 0 Plan.imaging_min_per_face 1], ...
        'FaceColor',imc,'EdgeColor','w','Parent',ax1);
    text(x0+Plan.imaging_min_per_face/2,0.5,sprintf('F%d',f),'Parent',ax1, ...
        'HorizontalAlignment','center','FontSize',8,'Color','w','FontWeight','bold');
    x0 = x0 + Plan.imaging_min_per_face;

    rectangle('Position',[x0 0 P.face_margin_min 1], ...
        'FaceColor',marc,'EdgeColor','w','Parent',ax1);
    x0 = x0 + P.face_margin_min;

    if f < P.n_faces
        rectangle('Position',[x0 0 P.rot_time_min 1], ...
            'FaceColor',rotc,'EdgeColor','w','Parent',ax1);
        x0 = x0 + P.rot_time_min;
    end
end

total_min = x0;
xlim(ax1,[0 total_min]); ylim(ax1,[0 1]);
set(ax1,'YTick',[],'XTick',0:30:ceil(total_min/30)*30);
xlabel(ax1,'Time within one inspection cycle (minutes)');
title(ax1,sprintf(['Contiguous off-Sun target-pointing interval = %.2f h (%.0f min) per cycle' ...
    '   |   6 faces x (%.1f min img + %.0f min margin) + 5 x %.0f min rotation'], ...
    Plan.cycle_hr, total_min, Plan.imaging_min_per_face, P.face_margin_min, P.rot_time_min));
box(ax1,'on');

h1 = patch('XData',nan,'YData',nan,'FaceColor',imc,'EdgeColor','none');
h2 = patch('XData',nan,'YData',nan,'FaceColor',marc,'EdgeColor','none');
h3 = patch('XData',nan,'YData',nan,'FaceColor',rotc,'EdgeColor','none');
legend([h1 h2 h3],{'Imaging','Margin / onboard validation','Rotation 90\circ @ 0.15\circ/s'}, ...
    'Location','northoutside','Orientation','horizontal','FontSize',8);

% (b) off-Sun vs Sun-available in one inspection day 
ax2 = subplot(2,1,2); hold(ax2,'on');

offsun   = Plan.cycle_hr + P.downlink_is_offSun * P.contact_hr;
sunavail = P.period_hr - offsun;
segs = [offsun, sunavail];

cols = [0.85 0.33 0.30; 0.97 0.80 0.27];
txtc = [1 1 1; 0 0 0];
labs = {sprintf('Off-Sun / target-pointing\n%.2f h = %.1f%%', offsun, offsun/P.period_hr*100), ...
        sprintf('Sun-available\n%.2f h = %.1f%%', sunavail, sunavail/P.period_hr*100)};

x0 = 0;
for k = 1:2
    rectangle('Position',[x0 0 segs(k) 1],'FaceColor',cols(k,:), ...
        'EdgeColor','w','LineWidth',1.5,'Parent',ax2);
    text(x0+segs(k)/2,0.5,labs{k},'Parent',ax2,'Color',txtc(k,:), ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'FontSize',9,'FontWeight','bold');
    x0 = x0 + segs(k);
end

xlim(ax2,[0 P.period_hr]); ylim(ax2,[0 1]);
set(ax2,'YTick',[],'XTick',0:2:P.period_hr);
xlabel(ax2,'Hours in one inspection day');
title(ax2,sprintf('Off-Sun per day = %.2f h   |   cumulative over %d-day nominal campaign = %.1f h', ...
    offsun, P.insp_days, offsun * P.insp_days));
box(ax2,'on');

sgtitle('ODIN  |  Off-Sun (Sun-Avoidance) Duration','FontWeight','bold','FontSize',13);

if exist('exportgraphics','file')
    exportgraphics(gcf,'Fig_ODIN_Off_Sun.png','Resolution',300);
    exportgraphics(gcf,'Fig_ODIN_Off_Sun.pdf');
end
drawnow;
end


function plot_range_vs_datarate_6dB(P)

r_AU = linspace(0.70, 2.00, 400);

% HGA curve using 1/R^2 scaling 
K_HGA = mean([ ...
    P.hk_nom_dl_kbps * P.hk_nom_range_AU^2; ...
    P.hk_far_dl_kbps * P.hk_far_range_AU^2 ]);

HGA_kbps = K_HGA ./ (r_AU.^2);

figure('Position',[80 80 1100 700], ...
       'Name','HGA Range vs Downlink Data Rate at 6 dB Margin');

hold on; grid on; box on;

patch([1.0 2.0 2.0 1.0], [0 0 140 140], ...
      [0.92 0.92 0.92], ...
      'EdgeColor','none', ...
      'FaceAlpha',0.35, ...
      'HandleVisibility','off');

% Main HGA curve
h1 = plot(r_AU, HGA_kbps, 'b-', 'LineWidth', 2.8, ...
    'DisplayName','HGA achievable rate @ 6 dB margin');

% 1.0 AU and 2.0 AU anchor points
h2 = plot([P.hk_nom_range_AU, P.hk_far_range_AU], ...
          [P.hk_nom_dl_kbps,  P.hk_far_dl_kbps], ...
          'kd', 'MarkerSize', 8, ...
          'MarkerFaceColor','w', ...
          'LineWidth',1.5, ...
          'DisplayName','HGA anchor points (1.0 AU, 2.0 AU)');

% Inspection points
h3 = plot(P.insp1_range_AU, P.insp1_dl_kbps, 'o', ...
    'MarkerSize', 9, ...
    'MarkerFaceColor',[0.2 0.7 0.2], ...
    'MarkerEdgeColor','k', ...
    'LineWidth',1.2, ...
    'DisplayName','Inspection 1');

h4 = plot(P.insp2_range_AU, P.insp2_dl_kbps, 's', ...
    'MarkerSize', 9, ...
    'MarkerFaceColor',[0.2 0.8 1.0], ...
    'MarkerEdgeColor','k', ...
    'LineWidth',1.2, ...
    'DisplayName','Inspection 2');

% Vertical guide lines without cluttering legend
xline(1.0, ':k', '1.0 AU', ...
    'LabelVerticalAlignment','bottom', ...
    'HandleVisibility','off');

xline(2.0, ':k', '2.0 AU', ...
    'LabelVerticalAlignment','bottom', ...
    'HandleVisibility','off');

xlabel('Earth-ODIN Range (AU)');
ylabel('Achievable HGA Downlink Data Rate (kbps)');

title({'ODIN HGA Downlink Capability vs Earth Range', ...
       'Fixed 6 dB Link Margin'});

xlim([0.70 2.00]);
ylim([0 140]);

legend([h1 h2 h3 h4], 'Location','northeast');

% Labels
text(P.insp1_range_AU + 0.015, P.insp1_dl_kbps, ...
    sprintf('Insp. 1: %.3f AU, %d kbps', ...
    P.insp1_range_AU, P.insp1_dl_kbps), ...
    'FontSize',10);

text(P.insp2_range_AU + 0.015, P.insp2_dl_kbps - 6, ...
    sprintf('Insp. 2: %.3f AU, %d kbps', ...
    P.insp2_range_AU, P.insp2_dl_kbps), ...
    'FontSize',10);

text(1.03, P.hk_nom_dl_kbps + 3, ...
    sprintf('1.0 AU: %.1f kbps', P.hk_nom_dl_kbps), ...
    'FontSize',10);

text(1.82, P.hk_far_dl_kbps + 3, ...
    sprintf('2.0 AU: %.1f kbps', P.hk_far_dl_kbps), ...
    'FontSize',10);

text(1.35, 128, 'Shaded region = requested 1.0-2.0 AU sweep', ...
    'FontSize',10, 'HorizontalAlignment','center');

% Export
exportgraphics(gcf, 'Fig_HGA_Range_vs_DataRate_6dB.png', 'Resolution', 300);
exportgraphics(gcf, 'Fig_HGA_Range_vs_DataRate_6dB.pdf');

% Save sweep table
SweepTable = table(r_AU(:), HGA_kbps(:), ...
    'VariableNames', {'Range_AU','HGA_kbps_6dB'});
writetable(SweepTable, 'Table_HGA_Range_vs_DataRate_6dB.csv');

fprintf('\nSaved HGA-only range-vs-data-rate plot:\n');
fprintf('  Fig_HGA_Range_vs_DataRate_6dB.png\n');
fprintf('  Fig_HGA_Range_vs_DataRate_6dB.pdf\n');
fprintf('  Table_HGA_Range_vs_DataRate_6dB.csv\n');
end
clear, clc, close all

%% Simulation time
stopTime = 10;
timeStep = 0.05;

%% 6U CubeSat
mass = 12;
dimz = 360/1000;
dimy = 100/1000;
dimx = 226.3/1000;
Izz  = 1/12*mass*(dimx^2+dimy^2);
Iyy  = 1/12*mass*(dimx^2+dimz^2);
Ixx  = 1/12*mass*(dimy^2+dimz^2);
Ixy  = 0; Ixz = 0; Iyz = 0;

I = [Ixx Ixy Ixz; Ixy Iyy Iyz; Ixz Iyz Izz];

%% Orbit 
mu_E       = 3.986004418e14;  
Omega_E    = 7.2921159e-5;   % [rad/s]
dOmega_dt  = 0.19910213e-6;
J2         = 1.082635854e-3;
R_E        = 6378*1000;
H          = 250*1000;
sma        = R_E + H;
ecc        = 0.001*0;
inc_SSO    = acosd(-2/3*dOmega_dt/J2*(sma/R_E)^2*sqrt(sma^3/mu_E));
RAAN       = 237.3113;
aop        = 0;
truean     = 0;
orbPeriod  = 2*pi*sqrt(sma^3/mu_E);
meanMotion = sqrt(mu_E/sma^3);

%% Epoch
yearValue   = 2025;
monthValue  = 1;
dayValue    = 1;
hourValue   = 12;        
minuteValue = 0;
secondValue = 0;

jdate = juliandate(yearValue, monthValue,  dayValue, ...
                   hourValue, minuteValue, secondValue);

%% Initial Attitude
roll      = deg2rad(0.2);
pitch     = deg2rad(0.5);
yaw       = deg2rad(0.1);
quat0_Err = eul2quat([yaw, pitch, roll], "ZYX");
quat0     = [0.6387; -0.3737; 0.6003; 0.3034];
w0x       = deg2rad(1);
w0y       = deg2rad(1);
w0z       = deg2rad(1);
w0        = [w0x; w0y; w0z];

%% Other specifications
res_dipole = 0.05;
CD         = 2.2;
q          = 0.6;
Phi        = 1358;
c          = 299792458;
rcp        = [0.013 0.02 0.05];
rand_vec   = [rand(), rand(), rand()];
rand_vec   = rand_vec/norm(rand_vec);

%% Reaction Wheels parameters
wDiam     = 27/1000;
wHeigth   = 18/1000;
wMass     = 100/1000;
I_w       = 0.5*wMass*wDiam^2/4;
I_W       = [I_w 0 0; 0 I_w 0; 0 0 I_w];
max_speed = 10000*pi/30;
max_h     = I_w*max_speed;
max_t     = 2e-3;

%% Controller Gains
kd = 0.022;
kq = 0.0032;

%% GPS parameters
GPSHAccuracy   = 10; % [m]
GPSVAccuracy   = 10; % [m]
GPSVelAccuracy = 0.1; % [m/2]

%% Camera parameters
FL      = 50e-3;      % Focal length [m]
L_pixel = 4.8e-6;     % Pixel size [m]
fps     = 1/timeStep; % frame rate [Hz]
K_optics = FL/(L_pixel*fps);

% Axis pointing mount
pointing_body = [0,0,1];

%% Kalman filter
LoS_0      = H*transpose(quat2dcm(reshape(quat0, 1, [])))*pointing_body';
b_0        = [0;0;0];
x0_Kfilter = [LoS_0,;b_0];
P0_Kfilter = blkdiag(eye(3), eye(3));

Q_b    = 0.05*eye(3);
Q_LoS  = 0.1*eye(3);
Q_sys  = blkdiag(Q_LoS, Q_b);
R_meas = norm(LoS_0)*L_pixel*fps/FL*Q_b;

%% Control parameters
controller_ON = 1;
env_torques_ON = 1;

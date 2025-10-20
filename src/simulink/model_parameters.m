function p = model_parameters(timeStep,op,attitude,angular_velocity,startTime)
    % MODEL_PARAMETERS Initializes spacecraft and simulation parameters.
    %
    % p = model_parameters(timeStep, op, attitude, angular_velocity, startTime)
    %
    % Input Arguments:
    %   timeStep - Simulation timestep [s]
    %     scalar
    %   op - Orbital parameters [sma, ecc, inc, RAAN, aop, truean]
    %     6-by-1 array
    %   attitude - Initial quaternion [q1 q2 q3 q4]
    %     4-by-1 array
    %   angular_velocity - Initial angular velocity [rad/s]
    %     3-by-1 array
    %   startTime - datetime object for simulation start
    %     scalar
    %
    % Output Arguments:
    % p - Structure containing all model and simulation parameters.
    %% Timestep
    p.timeStep = timeStep;

    %% 6U CubeSat mass distribution
    p.mass = 12;
    p.dimz = 360/1000;
    p.dimy = 100/1000;
    p.dimx = 226.3/1000;
    p.Izz  = 1/12*p.mass*(p.dimx^2+p.dimy^2);
    p.Iyy  = 1/12*p.mass*(p.dimx^2+p.dimz^2);
    p.Ixx  = 1/12*p.mass*(p.dimy^2+p.dimz^2);
    p.Ixy  = 0; p.Ixz = 0; p.Iyz = 0;
    
    p.I = [p.Ixx p.Ixy p.Ixz; p.Ixy p.Iyy p.Iyz; p.Ixz p.Iyz p.Izz];
    
    %% Orbit 
    p.mu_E       = 3.986004418e14;  
    p.Omega_E    = 7.2921159e-5;   % [rad/s]
    p.dOmega_dt  = 0.19910213e-6;
    p.J2         = 1.082635854e-3;
    p.R_E        = 6378*1000;
    p.sma        = op(1);
    p.ecc        = op(2);
    p.inc_SSO    = acosd(-2/3*p.dOmega_dt/p.J2*(p.sma/p.R_E)^2*sqrt(p.sma^3/p.mu_E)); %TODO: where should I move this calculation?
    p.RAAN       = op(4);
    p.aop        = op(5);
    p.truean     = op(6);
    p.orbPeriod  = period(p.sma,p.mu_E);
    p.meanMotion = sqrt(p.mu_E/p.sma^3);
    p.H          = p.sma-p.R_E;
    
    %% Epoch
    p.yearValue   = startTime.Year;
    p.monthValue  = startTime.Month;
    p.dayValue    = startTime.Day;
    p.hourValue   = startTime.Hour;        
    p.minuteValue = startTime.Minute;
    p.secondValue = startTime.Second;
    p.jdate       = juliandate(startTime);
    
    %% Initial Attitude
    p.quat0     = [attitude(1); attitude(2); attitude(3); attitude(4)];
    p.w0x       = angular_velocity(1);
    p.w0y       = angular_velocity(2);
    p.w0z       = angular_velocity(3);
    p.w0        = [p.w0x; p.w0y; p.w0z];
    
    %% Other specifications
    p.res_dipole = 0.05;
    p.CD         = 2.2;
    p.q          = 0.6;
    p.Phi        = 1358;
    p.c          = 299792458;
    p.rcp        = [0.013 0.02 0.05];
    p.rand_vec   = [rand(), rand(), rand()];
    p.rand_vec   = p.rand_vec/norm(p.rand_vec);
    
    %% Reaction Wheels parameters
    p.wDiam     = 27/1000;
    p.wHeigth   = 18/1000;
    p.wMass     = 100/1000;
    p.I_w       = 0.5*p.wMass*p.wDiam^2/4;
    p.I_W       = [p.I_w 0 0; 0 p.I_w 0; 0 0 p.I_w];
    p.max_speed = 10000*pi/30;
    p.max_h     = p.I_w*p.max_speed;
    p.max_t     = 2e-3;
    
    %% Controller Gains
    p.kd = 0.022;
    p.kq = 0.0032;
    
    %% GPS parameters
    p.GPSHAccuracy   = 10; % [m]
    p.GPSVAccuracy   = 10; % [m]
    p.GPSVelAccuracy = 0.1; % [m/s]
    
    %% Camera parameters
    p.FL       = 50e-3;      % Focal length [m]
    p.L_pixel  = 4.8e-6;     % Pixel size [m]
    p.fps      = 1/p.timeStep; % frame rate [Hz]
    p.K_optics = p.FL/(p.L_pixel*p.fps);
    
    % Axis pointing mount
    p.pointing_body = [0,0,1];
    
    %% Kalman filter
    p.LoS_0      = p.H*transpose(quat2dcm(reshape(p.quat0, 1, [])))*p.pointing_body';
    p.b_0        = [0;0;0];
    p.x0_Kfilter = [p.LoS_0;p.b_0];
    p.P0_Kfilter = blkdiag(eye(3), eye(3));
    
    p.Q_b    = 0.05*eye(3);
    p.Q_LoS  = 0.1*eye(3);
    p.Q_sys  = blkdiag(p.Q_LoS, p.Q_b);
    p.R_meas = norm(p.LoS_0)*p.L_pixel*p.fps/p.FL*p.Q_b;

    %% Control switches
    p.controller_ON = 1;
    p.torques_ON = 1;

end
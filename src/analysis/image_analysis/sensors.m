function cfg = sensors(name)

switch lower(name)

    case 'cmv12000'
        cfg.name = "CMV12000";
        cfg.full_well = 13500;
        cfg.gain = 255/cfg.full_well;
        cfg.px = 5.5*10^-6;

    case 'imx249'
        cfg.name = "IMX249";
        cfg.full_well = 33624;
        cfg.gain = 255/cfg.full_well;
        cfg.px = 5.86*10^-6;

    case 'gmax3265'
        cfg.name = "GMAX3265";
        cfg.full_well = 10600;
        cfg.gain = 255/cfg.full_well;
        cfg.px = 3.2*10^-6;

    case 'cis2521'
        cfg.name = "CIS2521";
        cfg.full_well = 30000;
        cfg.gain = 255/cfg.full_well;
        cfg.px = 6.5*10^-6;

    case 'vita1300'
        cfg.name = "VITA1300";
        cfg.full_well = 13700;
        cfg.gain = 255/cfg.full_well;
        cfg.px = 4.8*10^-6;

    otherwise
        error('Unknown sensor: %s', name);
end
end
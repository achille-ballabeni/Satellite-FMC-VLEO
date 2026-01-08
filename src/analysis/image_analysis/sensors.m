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

    otherwise
        error('Unknown sensor: %s', name);
end
end
function cfg = sensors(name)

switch lower(name)
    case 'triscape100'
        cfg.name = "TriScape100";
        cfg.full_well = 13500;
        cfg.gain = 255/cfg.full_well;
        cfg.f = 580*10^-3;
        cfg.D = 95*10^-3;
        cfg.px = 5.5*10^-6;

    otherwise
        error('Unknown sensor: %s', name);
end
end
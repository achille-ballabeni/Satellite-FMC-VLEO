function cfg = payload_optics(name)

switch lower(name)
    case 'triscape100'
        cfg.name = "TriScape100";
        cfg.f = 580*10^-3;
        cfg.D = 95*10^-3;
        cfg.tau = 0.7;

    case '2m@250'
        cfg.name = "2m@250";
        cfg.f = 687.5*10^-3;
        cfg.D = 95*10^-3;
        cfg.tau = 0.7;

    case '1.5m@250'
        cfg.name = "1.5m@250";
        cfg.f = 916.7*10^-3;
        cfg.D = 95*10^-3;
        cfg.tau = 0.7;

    case '1m@250'
        cfg.name = "1m@250";
        cfg.f = 1375*10^-3;
        cfg.D = 95*10^-3;
        cfg.tau = 0.7;

    case '0.5m@250'
        cfg.name = "0.5m@250";
        cfg.f = 2750*10^-3;
        cfg.D = 95*10^-3;
        cfg.tau = 0.7;

    case 'triscape200'
        cfg.name = "TriScape200";
        cfg.f = 1067*10^-3;
        cfg.D = 190*10^-3;
        cfg.tau = 0.7;

    case 'simulator'
        cfg.name = "simulator";
        cfg.f = 50*10^-3;
        cfg.D = 4.45*10^-3;
        cfg.tau = 0.7;

    otherwise
        error('Unknown payload optics: %s', name);
end
end
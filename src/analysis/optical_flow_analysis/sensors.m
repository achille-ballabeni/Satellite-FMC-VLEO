function cfg = sensors(name)

switch lower(name)
    case 'triscape100'
        cfg.name = "TriScape100";
        cfg.full_well = 13500;
        cfg.gain = 255/cfg.full_well;
        cfg.f = 580*10^-3;
        cfg.D = 95*10^-3;
        cfg.px = 5.5*10^-6;

    case '2m@250'
        cfg.name = "2m@250";
        cfg.full_well = 13500;
        cfg.gain = 255/cfg.full_well;
        cfg.f = 687.5*10^-3;
        cfg.D = 95*10^-3;
        cfg.px = 5.5*10^-6;

    case '1.5m@250'
        cfg.name = "1.5m@250";
        cfg.full_well = 13500;
        cfg.gain = 255/cfg.full_well;
        cfg.f = 916.7*10^-3;
        cfg.D = 95*10^-3;
        cfg.px = 5.5*10^-6;

    case '1m@250'
       cfg.name = "1m@250";
       cfg.full_well = 13500;
       cfg.gain = 255/cfg.full_well;
       cfg.f = 1375*10^-3;
       cfg.D = 95*10^-3;
       cfg.px = 5.5*10^-6;

    case '0.5m@250'
       cfg.name = "0.5m@250";
       cfg.full_well = 13500;
       cfg.gain = 255/cfg.full_well;
       cfg.f = 2750*10^-3;
       cfg.D = 95*10^-3;
       cfg.px = 5.5*10^-6;

    otherwise
        error('Unknown sensor: %s', name);
end

% From 6SV with settings:
% CMV 12000 sensor | BetaAngle=22.5deg | 0.3 lambertian
toa_photon_flux_RED = 3.05868*10^20;
dlambda_RED = 0.1014099;

toa_photon_flux_GREEN = 3.07001*10^20;
dlambda_GREEN = 0.088836;

toa_photon_flux_BLUE = 2.90814*10^20;
dlambda_BLUE = 0.0788317;

k = pi/4*(cfg.D/cfg.f)^2*cfg.px^2;

cfg.photon_flux_RED = k*toa_photon_flux_RED*dlambda_RED;
cfg.photon_flux_GREEN = k*toa_photon_flux_GREEN*dlambda_GREEN;
cfg.photon_flux_BLUE = k*toa_photon_flux_BLUE*dlambda_BLUE;

end
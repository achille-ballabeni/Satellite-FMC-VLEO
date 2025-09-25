clear, clc, close all

yearValue   = 2025;
monthValue  = 1;
dayValue    = 1;
hourValue   = 12;        
minuteValue = 0;
secondValue = 0;
StartTime   = datetime(yearValue, monthValue,  dayValue, ...
                       hourValue, minuteValue, secondValue);
duration    = 200;
StopTime    = StartTime + seconds(duration);
sampleTime  = 0.1;
sc          = satelliteScenario(StartTime, StopTime, sampleTime);

load("SatAtt.mat");
load("SatPos.mat");

position = array2timetable(SatPos(2:end, :)', "SampleRate", 1/sampleTime);
position.data = [position.Var1, position.Var2, position.Var3];
position(:, {'Var1', 'Var2', 'Var3'}) = [];

sat = satellite(sc, position, "CoordinateFrame",  "inertial", ...
                                         "Name", "SpaceitUp");

attitude = array2timetable(SatAtt(2:end, :)', "SampleRate", 1/sampleTime);
attitude.data = [attitude.Var1, attitude.Var2, attitude.Var3, attitude.Var4];
attitude(:, {'Var1', 'Var2', 'Var3', 'Var4'}) = [];

snsr = conicalSensor(sat, MaxViewAngle = 5, MountingLocation = [0 0 1]);
fieldOfView(snsr);

pointAt(sat, attitude, "CoordinateFrame",   "inertial", ...
                                "Format", "quaternion");

viewer1 = satelliteScenarioViewer(sc);
viewer1.CameraReferenceFrame = "Inertial";
sat.Visual3DModel = "SmallSat.glb";
coordinateAxes(sat, Scale = 2);
camtarget(viewer1, sat);

load("targetLLA.mat");

% We need to force the altitude to be a non-negative number because in the
% model we assumed a spherical Earth while the Simulink conversion block 
% assumes the WGS84 Earth model.
for i = 1:length(targetLLA(4,:))
    if targetLLA(4,i) < 0
        targetLLA(4,i) = 0;
    end
end

trajectory = geoTrajectory(targetLLA(2:4,:)', 0:sampleTime:duration);

pltf = platform(sc, trajectory, "Name", "Target");
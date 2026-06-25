function handles = Newtopoplot(Values, chanlocs, eegtopoSet, varargin)
%NEWTOPOPLOT Self-contained EEG topography/connectivity plotting.
%
% handles = Newtopoplot(Values, chanlocs, eegtopoSet, ...)
%
% This implementation keeps the original plugin interface and reproduces
% the EEGtopoSet geometry. The external arrow helper is not required.
%
% Common options:
%   'CLim'              [min max], default [0 1]
%   'electrodes'        'off'|'on'|'numbers'|'labels', default 'on'
%   'plotchans'         channel indices, default all channels
%   'plotrad'           head radius in EEGLAB polar units, default 0.55
%   'isInside'          true/false, default false
%   'headColor'         RGB, default [0 0 0]
%   'headLineWidth'     scalar, default 1.5
%   'electrodeSize'     marker size, default 20
%   'electrodeColor'    RGB, default [0 0 0]
%   'textColor'         RGB, default [0 0 0]
%   'textSize'          scalar, default 10
%   'numContour'        contour count, default 0
%   'shading'           'interp'|'flat', default 'interp'
%   'colormap'          n x 3 colormap, default local CBar()
%   'isDirection'       directed connectivity, default false
%   'LineWidth'         connectivity line width, default 2
%   'LineColor'         RGB, default [0 0 0]
%   'Axes'              target axes, default gca
%   'gridScale'         interpolation grid resolution, default 90
%   'coordScale'        plot coordinate scale, default 1
%   'boundaryAnchors'   add mean-valued head-boundary anchors, default false

if nargin < 3 || isempty(eegtopoSet)
    eegtopoSet = [];
end
eegtopoSet = resolveEegTopoSet(eegtopoSet);

settings = defaultSettings(chanlocs);
settings = parseOptions(settings, varargin{:});

ax2plot = settings.axes;
handles = struct();
handles.axes = ax2plot;
hold(ax2plot, 'on');
colormap(ax2plot, settings.colorMap);

[xAll, yAll, validLocation] = chanlocsToTopoCoordinates(chanlocs, ...
    settings.plotrad, settings.coordScale, eegtopoSet);
plotchans = normalizePlotChans(settings.plotchans, numel(chanlocs), validLocation);
if settings.isInside
    channelRadius = getChannelRadius(chanlocs);
    plotchans = plotchans(channelRadius(plotchans) < 0.5495);
end

x = xAll(plotchans);
y = yAll(plotchans);
allchansind = plotchans(:);
headScale = settings.coordScale;

drawHead(ax2plot, headScale, settings.headColor, settings.headLineWidth, eegtopoSet);
configureAxes(ax2plot, headScale, settings.CLim, eegtopoSet);

if isempty(Values)
    plotElectrodes(ax2plot, x, y, chanlocs, plotchans, allchansind, settings);
    title(ax2plot, [num2str(numel(plotchans)), ' of ', num2str(numel(chanlocs)), ' channels']);
    return
end

if isvector(Values) && ~(isrow(Values) && any(numel(Values) == [2 3]))
    Values = Values(:);
end

if size(Values, 2) == 1
    handles = plotTopoValues(handles, ax2plot, Values, xAll, yAll, plotchans, ...
        headScale, chanlocs, allchansind, settings, eegtopoSet);
else
    handles = plotConnectivity(handles, ax2plot, Values, xAll, yAll, plotchans, ...
        settings);
    plotElectrodes(ax2plot, x, y, chanlocs, plotchans, allchansind, settings);
end
end


function settings = defaultSettings(chanlocs)
settings = struct();
settings.CONTOURNUM = 0;
settings.ELECTRODES = 'on';
settings.isInside = false;
settings.isDir = false;
settings.plotrad = 0.55;
settings.SHADING = 'interp';
settings.headColor = [0 0 0];
settings.electrodeColor = [0 0 0];
settings.textColor = [0 0 0];
settings.lineColor = [0 0 0];
settings.LineWidth = 2;
settings.CLim = [0 1];
settings.colorMap = CBar();
settings.electrodeSize = 20;
settings.headLineWidth = 1.5;
settings.plotchans = 1:numel(chanlocs);
settings.textSize = 10;
settings.axes = gca;
settings.gridScale = 90;
settings.coordScale = 1;
settings.boundaryAnchors = false;
end


function settings = parseOptions(settings, varargin)
if mod(numel(varargin), 2) ~= 0
    error('Optional inputs must be name-value pairs.');
end
for iter = 1:2:numel(varargin)
    param = lower(string(varargin{iter}));
    value = varargin{iter + 1};
    switch param
        case {'numcontour', 'contournum'}
            settings.CONTOURNUM = value;
        case 'electrodes'
            settings.ELECTRODES = lower(char(value));
        case 'plotrad'
            settings.plotrad = value;
        case 'shading'
            settings.SHADING = char(value);
            if ~any(strcmpi(settings.SHADING, {'flat', 'interp'}))
                error('Invalid shading parameter.');
            end
        case 'headcolor'
            settings.headColor = validateRgb(value, 'headColor');
        case {'electrodecolor', 'electrodcolor'}
            settings.electrodeColor = validateRgb(value, 'electrodeColor');
        case 'textcolor'
            settings.textColor = validateRgb(value, 'textColor');
        case 'linewidth'
            settings.LineWidth = value;
        case 'linecolor'
            settings.lineColor = validateRgb(value, 'lineColor');
        case 'colormap'
            settings.colorMap = value;
            if size(value, 2) ~= 3
                error('Colormap must be an n x 3 matrix.');
            end
        case 'electrodesize'
            settings.electrodeSize = value;
        case 'headlinewidth'
            settings.headLineWidth = value;
        case 'clim'
            settings.CLim = value;
            if numel(settings.CLim) ~= 2 || any(~isfinite(settings.CLim)) || ...
                    settings.CLim(2) <= settings.CLim(1)
                error('Color Limit must be a finite increasing 1 x 2 vector.');
            end
        case 'isinside'
            settings.isInside = logical(value);
        case {'isdirection', 'isdir'}
            settings.isDir = logical(value);
        case 'plotchans'
            settings.plotchans = value;
        case 'textsize'
            settings.textSize = value;
        case 'axes'
            settings.axes = value;
        case 'gridscale'
            settings.gridScale = max(25, min(180, round(value)));
        case 'coordscale'
            settings.coordScale = value;
        case {'boundaryanchors', 'addboundaryanchors'}
            settings.boundaryAnchors = logical(value);
        otherwise
            warning('Unknown Newtopoplot option: %s', param);
    end
end
end


function rgb = validateRgb(value, name)
if ~isnumeric(value) || numel(value) ~= 3
    error('%s must be a 1 x 3 RGB vector.', name);
end
rgb = reshape(value, 1, 3);
end


function eegtopoSet = resolveEegTopoSet(eegtopoSet)
if ~isempty(eegtopoSet)
    return
end
eegtopoSet = localEegTopoSet();
end


function eegtopoSet = localEegTopoSet()
% Built-in copy of the geometry used by EEGtopoSet.mat. The head curves are
% stored as their Fourier8 coefficients; the ear and nose curves are the
% EEGtopoSet coordinates. This removes the runtime dependency on the MAT
% file while preserving the same plotting geometry.
eegtopoSet.hhead = struct("type", "fourier8", "coefficients", ...
    [21798708279.957691,0,-160231800721.5354,-108325867622.62846, ...
    228506186354.35034,189562035248.80185,-159518916384.29831, ...
    -162287771308.86362,39167255257.567123,75247461951.686234, ...
    19702999553.078663,-17296891158.970837,-16803818390.527815, ...
    1198954600.9459865,4340245062.2400331,103360376.51658186, ...
    -370783137.24359548,0.0014241313497940929]);
eegtopoSet.lhead = struct("type", "fourier8", "coefficients", ...
    [-35849355106.229042,0,140286489655.74344,121737002809.49521, ...
    -142306872812.8967,-153520927668.53159,45724029439.306221, ...
    92922028441.470245,24163927670.406849,-28524586322.936832, ...
    -28965738408.707253,2734143122.6929584,11360422570.746656, ...
    629514275.20374143,-1958078591.8373351,-127812412.7337594, ...
    108990765.8826738,0.0014938449712378985]);

upperX = [-344:-72, -66:63, 69:344].';
lowerX = (344:-1:-344).';
upperY = evaluateHeadCurve(eegtopoSet.hhead, upperX + 409) - 355.5;
lowerY = evaluateHeadCurve(eegtopoSet.lhead, lowerX + 409) - 355.5;
eegtopoSet.Chead = [upperX, upperY; lowerX, lowerY; upperX(1), upperY(1)];

eegtopoSet.Cleft = [-344 -41.68323898;-345 -42.39538503;-346 -43.29046512;-347 -44.31084037;-348 -45.40718472;-349 -46.53754354;-350 -47.66697443;-351 -48.76683557;-352 -49.81452835;-353 -50.79220688;-354 -51.6871475;-355 -52.49074972;-356 -53.19801426;-357 -53.8073014;-358 -54.31974089;-359 -54.73892355;-360 -55.07039541;-361 -55.32126063;-362 -55.49992692;-363 -55.61568791;-364 -55.67844689;-365 -55.69817722;-366 -55.68502265;-367 -55.64872664;-368 -55.59850585;-369 -55.54283941;-370 -55.48931968;-371 -55.4441303;-372 -55.41228688;-373 -55.39738303;-374 -55.40132827;-375 -55.42423278;-376 -55.46458095;-377 -55.51875776;-378 -55.58150637;-379 -55.64549297;-380 -55.70124632;-381 -55.73767728;-382 -55.74153817;-383 -55.69775265;-384 -55.58957753;-385 -55.39835316;-386 -55.10410094;-387 -54.68507627;-388 -54.11842752;-389 -53.38008478;-390 -52.4450309;-391 -51.28744239;-392 -49.8810674;-393 -48.19935212;-394 -46.21568966;-395 -43.90385166;-396 -41.23808503;-397 -38.19371976;-398 -34.7471665;-399 -30.87648647;-400 -26.5621068;-400 2.58805955;-399 10.46149467;-398 17.23431928;-397 23.10049509;-396 28.22529623;-395 32.74805699;-394 36.78479992;-393 40.43074242;-392 43.76268147;-391 46.84125559;-390 49.71308207;-389 52.41276995;-388 54.9648071;-387 57.38532049;-386 59.68370977;-385 61.86415226;-384 63.92698018;-383 65.86992805;-382 67.68925087;-381 69.38071232;-380 70.94044199;-379 72.36566242;-377 74.81037097;-375 76.73381801;-374 77.51740196;-372 78.78650443;-371 79.30255305;-369 80.18737762;-368 80.59493492;-366 81.43508376;-363 82.97793904;-360 84.94392416;-358 86.25621177;-356 87.10739634;-354 86.77841703;-334.5 87.1];
eegtopoSet.Cright = [344 -41.28316073;345 -42.76551886;346 -43.72401158;347 -44.51337294;348 -45.32848668;349 -46.25259691;350 -47.29595035;351 -48.42583049;352 -49.58901331;353 -50.72770707;354 -51.7900382;355 -52.73611426;356 -53.54063813;357 -54.19296891;358 -54.69542948;359 -55.06055263;360 -55.30784282;361 -55.46051258;362 -55.54253659;363 -55.57625558;364 -55.58066128;365 -55.57040367;366 -55.55548702;367 -55.54156162;368 -55.53067539;369 -55.52232388;370 -55.51462726;371 -55.50546885;372 -55.49344806;373 -55.47853128;374 -55.46232198;375 -55.44791564;376 -55.4393509;377 -55.44071353;378 -55.45499049;379 -55.48280516;380 -55.52118783;381 -55.56254668;382 -55.59400095;383 -55.59721824;384 -55.54886232;385 -55.42170474;386 -55.18638488;387 -54.81371957;389 -53.55654277;390 -52.63837504;391 -51.51936441;392 -50.20530571;393 -48.70891421;394 -47.04430267;395 -45.21737142;396 -43.21111028;397 -40.96477223;398 -38.34586858;399 -35.11395751;400 -30.8752554;401 -25.02719547;401 1.129532668;400 9.980072718;399 17.1083889;398 22.90109496;397 27.69308176;396 31.7645283;395 35.34058498;394 38.59344282;393 41.64641999;392 44.57963683;391 47.43681512;390 50.23272636;389 52.96082698;388 55.60065354;387 58.12460568;386 60.50381389;385 62.71287058;384 64.73328976;383 66.55564909;382 68.18045308;381 69.61783309;380 70.88626472;379 72.01053295;378 73.01920812;377 73.94190918;376 74.80662629;375 75.63735124;374 76.45222541;373 77.26236253;372 78.07144065;371 78.87608991;370 79.66703228;368 81.1522986;366 82.41248237;363 83.76225548;360 84.70842243;358 85.42240012;356 86.34483643;353 87.55650886;334.3 87.6];
eegtopoSet.Cnose = [-71 442.3605258;-70 443.9130106;-69 445.2990442;-68 446.544838;-67 447.6752958;-66 448.713768;-65 449.681849;-64 450.5992194;-63 451.483532;-62 452.3503408;-61 453.2130709;-60 454.083027;-59 454.9694368;-58 455.8795256;-57 456.8186196;-56 457.7902718;-55 458.7964067;-54 459.8374804;-53 460.9126502;-52 462.0199505;-51 463.1564705;-50 464.3185298;-49 465.5018494;-48 466.7017141;-47 467.9131241;-46 469.1309343;-45 470.3499787;-44 471.5651795;-43 472.7716408;-42 473.9647246;-41 475.1401122;-40 476.2938493;-39 477.4223765;-38 478.5225471;-37 479.5916322;-36 480.6273159;-35 481.6276818;-34 482.5911919;-33 483.5166609;-32 484.4032263;-31 485.2503167;-30 486.0576193;-29 486.8250473;-28 487.5527098;-27 488.2408832;-26 488.8899859;-25 489.5005559;-24 490.0732326;-23 490.6087414;-22 491.1078817;-21 491.5715178;-20 492.0005726;-19 492.3960227;-18 492.7588949;-17 493.0902632;-16 493.3912462;-15 493.6630031;-14 493.9067288;-13 494.1236478;-12 494.3150051;-11 494.482056;-10 494.6260521;-9 494.7482265;-8 494.8497753;-7 494.9318389;-6 494.9954804;-5 495.0416638;-4 495.0712317;-3 495.0848836;-2 495.083155;-1 495.0663984;0 495.0347666;1 494.9881996;2 494.9264147;3 494.8489017;4 494.7549218;5 494.643512;6 494.5134952;7 494.3634941;8 494.1919515;9 493.9971546;10 493.7772639;11 493.5303457;12 493.2544085;13 492.9474409;14 492.6074518;15 492.2325115;16 491.820792;17 491.3706077;18 490.8804528;19 490.3490373;20 489.7753193;21 489.1585333;22 488.4982143;23 487.7942169;24 487.046729;25 486.256281;26 485.4237488;27 484.5503521;28 483.6376471;29 482.6875155;30 481.7021478;31 480.6840238;32 479.6358891;33 478.5607285;34 477.4617376;35 476.3422916;36 475.2059135;37 474.0562397;38 472.8969861;39 471.731912;40 470.5647847;41 469.3993418;42 468.2392539;43 467.0880848;44 465.9492518;45 464.8259825;46 463.7212706;47 462.6378283;48 461.5780359;49 460.5438879;50 459.5369351;51 458.5582237;52 457.6082293;53 456.6867886;54 455.793027;55 454.9252835;56 454.0810348;57 453.2568178;58 452.4481539;59 451.6494746;60 450.8540528;61 450.0539397;62 449.2399109;63 448.4014231;64 447.5265855;65 446.6021468;66 445.6135008;67 444.5447136;68 443.3785743;69 442.0966704];
end


function [xPlot, yPlot, validLocation] = chanlocsToTopoCoordinates(chanlocs, plotrad, coordScale, eegtopoSet)
channelCount = numel(chanlocs);
theta = nan(1, channelCount);
radius = nan(1, channelCount);
for ch = 1:channelCount
    if isfield(chanlocs(ch), 'theta') && ~isempty(chanlocs(ch).theta)
        theta(ch) = chanlocs(ch).theta;
    end
    if isfield(chanlocs(ch), 'radius') && ~isempty(chanlocs(ch).radius)
        radius(ch) = chanlocs(ch).radius;
    elseif isfield(chanlocs(ch), 'radiu') && ~isempty(chanlocs(ch).radiu)
        radius(ch) = chanlocs(ch).radiu;
    end
end

radius = radius * plotrad / 0.55;
[polarX, polarY] = pol2cart(theta * pi / 180, radius);

% Original Newtopoplot projection: xPlot is based on polarY; yPlot is based
% on polarX and warped to the EEGtopoSet upper/lower head boundary.
xPlot = polarY * 62.6;
yRaw = polarX * 62.6;
limitX = max(abs(eegtopoSet.Chead(:, 1)));
headMidX = 409;
headMidY = 355.5;
denominator = sqrt(max(0, limitX .^ 2 - xPlot .^ 2)) .* sign(yRaw);
upper = yRaw > 0;
targetY = xPlot;
targetY(upper) = evaluateHeadCurve(eegtopoSet.hhead, xPlot(upper) + headMidX) - headMidY;
targetY(~upper) = evaluateHeadCurve(eegtopoSet.lhead, xPlot(~upper) + headMidX) - headMidY;
yPlot = yRaw .* (targetY ./ denominator);
yPlot(~isfinite(yPlot)) = 0;

xPlot = xPlot * 10 * coordScale;
yPlot = yPlot * 10 * coordScale;
validLocation = isfinite(xPlot) & isfinite(yPlot);
end


function radius = getChannelRadius(chanlocs)
radius = nan(1, numel(chanlocs));
for ch = 1:numel(chanlocs)
    if isfield(chanlocs(ch), 'radius') && ~isempty(chanlocs(ch).radius)
        radius(ch) = chanlocs(ch).radius;
    elseif isfield(chanlocs(ch), 'radiu') && ~isempty(chanlocs(ch).radiu)
        radius(ch) = chanlocs(ch).radiu;
    end
end
end


function plotchans = normalizePlotChans(plotchans, channelCount, validLocation)
plotchans = unique(abs(plotchans(:).'), 'stable');
plotchans = plotchans(plotchans >= 1 & plotchans <= channelCount);
plotchans = plotchans(validLocation(plotchans));
end


function y = evaluateHeadCurve(curve, x)
if isa(curve, 'cfit')
    y = feval(curve, x(:));
    y = reshape(y, size(x));
elseif isstruct(curve) && isfield(curve, 'type') && strcmp(curve.type, 'fourier8')
    coefficients = curve.coefficients;
    a0 = coefficients(1);
    w = coefficients(end);
    y = a0 + zeros(size(x));
    cursor = 2;
    for harmonic = 1:8
        a = coefficients(cursor);
        b = coefficients(cursor + 1);
        y = y + a * cos(harmonic * x * w) + b * sin(harmonic * x * w);
        cursor = cursor + 2;
    end
else
    y = polyval(curve, x);
end
end


function drawHead(ax, headScale, headColor, headLineWidth, eegtopoSet)
[head, leftEar, rightEar, nose] = eegTopoSetOutline(headScale, eegtopoSet);
plot(ax, head(:, 1), head(:, 2), 'Color', headColor, 'LineWidth', headLineWidth);
plot(ax, leftEar(:, 1), leftEar(:, 2), 'Color', headColor, 'LineWidth', headLineWidth);
plot(ax, rightEar(:, 1), rightEar(:, 2), 'Color', headColor, 'LineWidth', headLineWidth);
plot(ax, nose(:, 1), nose(:, 2), 'Color', headColor, 'LineWidth', headLineWidth);
end


function configureAxes(ax, headScale, CLim, eegtopoSet)
[head, leftEar, rightEar, nose] = eegTopoSetOutline(headScale, eegtopoSet);
outline = [head; leftEar; rightEar; nose];
xMargin = 0.04 * range(outline(:, 1));
yMargin = 0.04 * range(outline(:, 2));
set(ax, 'XTick', [], 'YTick', [], 'DataAspectRatio', [1 1 1], ...
    'XLim', [min(outline(:, 1)) - xMargin, max(outline(:, 1)) + xMargin], ...
    'YLim', [min(outline(:, 2)) - yMargin, max(outline(:, 2)) + yMargin], ...
    'CLim', CLim, 'XColor', [0.9 0.95 1], 'YColor', [0.9 0.95 1], ...
    'ZColor', [0.9 0.95 1], 'Visible', 'off');
set(ax.Parent, 'Color', [1 1 1]);
end


function [head, leftEar, rightEar, nose] = eegTopoSetOutline(headScale, eegtopoSet)
head = eegtopoSet.Chead * headScale;
leftEar = eegtopoSet.Cleft * headScale;
rightEar = eegtopoSet.Cright * headScale;
nose = eegtopoSet.Cnose * headScale;
end


function handles = plotTopoValues(handles, ax, Values, xAll, yAll, plotchans, ...
        headScale, chanlocs, allchansind, settings, eegtopoSet)
if numel(Values) < max(plotchans)
    error('Values length must match channel count for topography plotting.');
end
values = Values(plotchans);
finite = isfinite(values) & isfinite(xAll(plotchans)).' & isfinite(yAll(plotchans)).';

plotX = xAll(plotchans);
plotY = yAll(plotchans);
plotX = plotX(finite);
plotY = plotY(finite);
plotValues = values(finite);

[headOutline, ~, ~, ~] = eegTopoSetOutline(headScale, eegtopoSet);
[Xi, Yi, coverX, coverY, localMask] = topoInterpolationGrid( ...
    plotX, plotY, plotchans, chanlocs, settings, headScale, eegtopoSet);

if numel(plotValues) >= 3
    interpX = plotX(:);
    interpY = plotY(:);
    interpValues = plotValues(:);
    if settings.boundaryAnchors
        boundaryIndex = unique(round(linspace(1, size(headOutline, 1), 80)));
        boundaryX = headOutline(boundaryIndex, 1);
        boundaryY = headOutline(boundaryIndex, 2);
        boundaryValue = repmat(mean(plotValues, 'omitnan'), numel(boundaryIndex), 1);
        interpX = [interpX; boundaryX];
        interpY = [interpY; boundaryY];
        interpValues = [interpValues; boundaryValue];
    end
    [interpX, interpY, interpValues] = mergeDuplicatePoints(interpX, interpY, interpValues);
    if numel(interpValues) >= 3 && rank([interpX - mean(interpX), interpY - mean(interpY)]) >= 2
        Zi = griddata(interpX, interpY, interpValues, Xi, Yi, 'v4');
        if any(isnan(Zi(:)))
            nearestZi = griddata(interpX, interpY, interpValues, Xi, Yi, 'nearest');
            Zi(isnan(Zi)) = nearestZi(isnan(Zi));
        end
    else
        Zi = nan(size(Xi));
    end
    if isempty(coverX)
        Zi(localMask) = nan;
    end
    handles.hsuf = surface(ax, Xi, Yi, zeros(size(Zi)), Zi, ...
        'EdgeColor', 'none', 'FaceColor', settings.SHADING, ...
        'FaceLighting', 'gouraud');
else
    Zi = nan(size(Xi));
    handles.hsuf = surface(ax, Xi, Yi, zeros(size(Zi)), Zi, ...
        'EdgeColor', 'none', 'FaceColor', settings.SHADING);
end

if ~isempty(coverX)
    drawCoverPatches(ax, coverX, coverY);
end

if settings.CONTOURNUM > 0 && any(isfinite(Zi(:)))
    contour(ax, Xi, Yi, Zi, settings.CONTOURNUM, 'LineColor', 'k');
end

drawHead(ax, headScale, settings.headColor, settings.headLineWidth, eegtopoSet);
plotElectrodes(ax, xAll(plotchans), yAll(plotchans), chanlocs, plotchans, ...
    allchansind, settings);
end


function [x, y, values] = mergeDuplicatePoints(x, y, values)
xy = round([x(:), y(:)] * 1e10) / 1e10;
[~, ~, group] = unique(xy, 'rows');
values = accumarray(group, values(:), [], @mean);
x = accumarray(group, x(:), [], @mean);
y = accumarray(group, y(:), [], @mean);
end


function [Xi, Yi, coverX, coverY, localMask] = topoInterpolationGrid( ...
        plotX, plotY, plotchans, chanlocs, settings, headScale, eegtopoSet)
channelRadius = getChannelRadius(chanlocs) * settings.plotrad / 0.55;
plottedRadius = channelRadius(plotchans);
plottedRadius = plottedRadius(isfinite(plottedRadius));
hasOutsideElectrode = ~settings.isInside && ~isempty(plottedRadius) && ...
    max(plottedRadius) >= 0.55;

if hasOutsideElectrode
    [~, farthestLocalIndex] = max(hypot(plotX, plotY));
    ratio = max(plottedRadius) / 0.55;
    xAxis = linspace(-344 * headScale * ratio * 1.16, ...
        344 * headScale * ratio * 1.16, settings.gridScale);
    yAxis = linspace((-349 * ratio * 1.16 - 5) * headScale, ...
        446 * headScale * ratio * 1.16, settings.gridScale);
    [Xi, Yi] = meshgrid(xAxis, yAxis);
    [upperLimit, lowerLimit] = outEllipScaled(abs(plotX(farthestLocalIndex)), ...
        plotY(farthestLocalIndex), Xi(1, :), headScale, eegtopoSet);
    regionX = Xi(1, :);
    regionUpper = upperLimit;
    regionLower = lowerLimit;
    [regionPolyX, regionPolyY] = regionFromUpperLower(regionX, regionUpper, regionLower);
    localMask = ~inpolygon(Xi, Yi, regionPolyX, regionPolyY);
    [coverX, coverY] = coverPatchesFromLimits(Xi, Yi, regionX, regionUpper, regionLower);
    return
end

if isempty(plotX)
    [headOutline, ~, ~, ~] = eegTopoSetOutline(headScale, eegtopoSet);
    xRange = [min(headOutline(:, 1)), max(headOutline(:, 1))];
    yRange = [min(headOutline(:, 2)), max(headOutline(:, 2))];
elseif isWholeHeadTopo(plotchans, chanlocs)
    xRange = [-344, 344] * headScale;
    headSampleX = linspace(xRange(1), xRange(2), settings.gridScale);
    [headUpperEdge, headLowerEdge] = headLimitsScaled(headSampleX, headScale, eegtopoSet);
    yRange = [min(headLowerEdge), max(headUpperEdge)];
else
    xRange = [max(min(plotX), -344 * headScale), min(max(plotX), 344 * headScale)];
    yRange = [min(plotY), max(plotY)];
end

if diff(xRange) <= eps
    xRange = xRange + [-1 1] * 25 * headScale;
end
if diff(yRange) <= eps
    yRange = yRange + [-1 1] * 25 * headScale;
end

x0 = mean(xRange);
y0 = mean(yRange);
if isWholeHeadTopo(plotchans, chanlocs)
    xAxis = linspace(xRange(1), xRange(2), settings.gridScale);
    yAxis = linspace(yRange(1), yRange(2), settings.gridScale);
else
    xAxis = linspace((xRange(1) - x0) * sqrt(2) * 1.3 + x0, ...
        (xRange(2) - x0) * sqrt(2) * 1.3 + x0, settings.gridScale);
    yAxis = linspace((yRange(1) - y0) * sqrt(2) * 1.3 + y0, ...
        (yRange(2) - y0) * sqrt(2) * 1.3 + y0, settings.gridScale);
end
[Xi, Yi] = meshgrid(xAxis, yAxis);

fXi = Xi(1, :);
if isWholeHeadTopo(plotchans, chanlocs)
    boundaryX = fXi;
else
    boundaryX = linspace(-344 * headScale, 344 * headScale, settings.gridScale);
end
outId = abs(boundaryX) > 344 * headScale;
[ellipseUpper, ellipseLower] = inEllipScaled(x0, y0, ...
    1.1 * max(abs(xRange - x0)) + x0, ...
    1.1 * max(abs(yRange - y0)) + y0, boundaryX);
[headUpper, headLower] = headLimitsScaled(boundaryX, headScale, eegtopoSet);
headUpper(outId) = 0;
headLower(outId) = 0;
upperLimit = min(headUpper(:), ellipseUpper(:)).';
lowerLimit = max(headLower(:), ellipseLower(:)).';
regionX = boundaryX(~outId);
regionUpper = upperLimit(~outId);
regionLower = lowerLimit(~outId);
[regionPolyX, regionPolyY] = regionFromUpperLower(regionX, regionUpper, regionLower);
localMask = ~inpolygon(Xi, Yi, regionPolyX, regionPolyY);
[coverX, coverY] = coverPatchesFromLimits(Xi, Yi, regionX, regionUpper, regionLower);
end


function wholeHead = isWholeHeadTopo(plotchans, chanlocs)
wholeHead = numel(plotchans) >= max(8, ceil(0.75 * numel(chanlocs)));
end


function [regionX, regionY] = regionFromUpperLower(x, upper, lower)
regionX = [x, x(end:-1:1), x(1)];
regionY = [upper, lower(end:-1:1), upper(1)];
end


function [coverX, coverY] = coverPatchesFromLimits(Xi, Yi, regionX, regionUpper, regionLower)
outerLeft = min(Xi(:));
outerRight = max(Xi(:));
outerBottom = min(Yi(:));
outerTop = max(Yi(:));
leftEdge = min(regionX);
rightEdge = max(regionX);
coverX = cell(1, 4);
coverY = cell(1, 4);
coverX{1} = [regionX, regionX(end:-1:1), regionX(1)];
coverY{1} = [regionUpper, outerTop + zeros(size(regionX)), regionUpper(1)];
coverX{2} = [regionX, regionX(end:-1:1), regionX(1)];
coverY{2} = [regionLower, outerBottom + zeros(size(regionX)), regionLower(1)];
coverX{3} = [outerLeft, leftEdge, leftEdge, outerLeft, outerLeft];
coverY{3} = [outerBottom, outerBottom, outerTop, outerTop, outerBottom];
coverX{4} = [rightEdge, outerRight, outerRight, rightEdge, rightEdge];
coverY{4} = [outerBottom, outerBottom, outerTop, outerTop, outerBottom];
end


function drawCoverPatches(ax, coverX, coverY)
backgroundColor = axesBackgroundColor(ax);
if iscell(coverX)
    for patchIndex = 1:numel(coverX)
        if isempty(coverX{patchIndex})
            continue
        end
        patch(ax, coverX{patchIndex}, coverY{patchIndex}, ...
            zeros(size(coverX{patchIndex})), backgroundColor, 'EdgeColor', 'none');
    end
else
    patch(ax, coverX, coverY, zeros(size(coverX)), backgroundColor, 'EdgeColor', 'none');
end
end


function [upper, lower] = headLimitsScaled(x, headScale, eegtopoSet)
xUnscaled = x / headScale;
upper = (evaluateHeadCurve(eegtopoSet.hhead, xUnscaled + 409) - 355.5) * headScale;
lower = (evaluateHeadCurve(eegtopoSet.lhead, xUnscaled + 409) - 355.5) * headScale;
end


function [upper, lower] = outEllipScaled(x, y, xi, headScale, eegtopoSet)
x = x / headScale;
y = y / headScale;
xi = xi / headScale;
headX = eegtopoSet.Chead(:, 1);
headY = eegtopoSet.Chead(:, 2);
headRight = max(abs(headX));
headUpper = max(headY);
headLower = abs(min(headY));
upperRadiusX = headRight*1.1;
lowerRadiusX = headRight * 1.1;
upperScale = max(1, sqrt((max(y, 0)) ^ 2 / headUpper ^ 2 + (x) ^ 2 / upperRadiusX ^ 2));
lowerScale = max(1, sqrt((max(-y, 0)) ^ 2 / headLower ^ 2 + (x) ^ 2 / lowerRadiusX ^ 2));
upper = upperScale ^ 2 * headUpper ^ 2 - headUpper ^ 2 / upperRadiusX ^ 2 .* (xi .^ 2);
lower = lowerScale ^ 2 * headLower ^ 2 - headLower ^ 2 / lowerRadiusX ^ 2 .* (xi .^ 2);
upper(upper < 0) = 0;
lower(lower < 0) = 0;
upper = sqrt(upper) * 1.05 * headScale;
lower = -sqrt(lower) * 1.1 * headScale;
end


function [upper, lower] = inEllipScaled(x0, y0, x, y, xi)
r1 = 2 * (y - y0) ^ 2;
r2 = 2 * (x - x0) ^ 2;
if r2 <= eps
    upper = y0 + zeros(size(xi));
    lower = y0 + zeros(size(xi));
    return
end
yt = r1 - r1 / r2 * (xi - x0) .^ 2;
yt(yt < 0) = 0;
yt = sqrt(yt);
upper = yt * 1.1 + y0;
lower = -yt * 1.1 + y0;
end


function color = axesBackgroundColor(ax)
color = get(ax.Parent, 'Color');
if ischar(color) || isstring(color) || numel(color) ~= 3
    color = [1 1 1];
end
end


function plotElectrodes(ax, x, y, chanlocs, plotchans, allchansind, settings)
if strcmp(settings.ELECTRODES, 'off')
    plot(ax, x, y, '.', 'MarkerSize', 0.001, 'Color', 'none');
    return
end

plot(ax, x, y, '.', 'MarkerSize', settings.electrodeSize, ...
    'Color', settings.electrodeColor);
labelOffset = 1.2 * settings.electrodeSize * settings.coordScale;
if strcmp(settings.ELECTRODES, 'labels')
    labels = getChanLabels(chanlocs, plotchans);
    text(ax, x, y + labelOffset, labels, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Color', settings.textColor, ...
        'HitTest', 'off', 'FontName', 'Arial', 'FontSize', settings.textSize);
elseif strcmp(settings.ELECTRODES, 'numbers')
    text(ax, x, y + labelOffset, num2str(allchansind(:)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'Color', settings.textColor, 'HitTest', 'off', ...
        'FontName', 'Arial', 'FontSize', settings.textSize);
end
end


function labels = getChanLabels(chanlocs, plotchans)
labels = cell(1, numel(plotchans));
for index = 1:numel(plotchans)
    channelIndex = plotchans(index);
    if isfield(chanlocs(channelIndex), 'labels') && ~isempty(chanlocs(channelIndex).labels)
        labels{index} = chanlocs(channelIndex).labels;
    else
        labels{index} = num2str(channelIndex);
    end
end
end


function handles = plotConnectivity(handles, ax, Values, xAll, yAll, plotchans, settings)
chanPair = Values(:, 1:2);
selfIdx = chanPair(:, 1) == chanPair(:, 2);
chanPair(selfIdx, :) = [];
Values(selfIdx, :) = [];

[isMember, localPair] = ismember(chanPair, plotchans);
validPair = isMember(:, 1) & isMember(:, 2);
chanPair = localPair(validPair, :);
Values = Values(validPair, :);
if isempty(chanPair)
    handles.connectivityLines = gobjects(0);
    return
end

if size(Values, 2) >= 3
    color2plot = valuesToColors(Values(:, 3), settings.CLim, settings.colorMap, settings.lineColor);
else
    color2plot = repmat(settings.lineColor, size(Values, 1), 1);
end

plotX = xAll(plotchans);
plotY = yAll(plotchans);
handles.connectivityLines = gobjects(size(chanPair, 1), 1);
for index = 1:size(chanPair, 1)
    startPoint = [plotX(chanPair(index, 1)), plotY(chanPair(index, 1))];
    endPoint = [plotX(chanPair(index, 2)), plotY(chanPair(index, 2))];
    if settings.isDir
        handles.connectivityLines(index) = drawDirectedLine(ax, startPoint, endPoint, ...
            color2plot(index, :), settings.LineWidth, settings.coordScale);
    else
        handles.connectivityLines(index) = line(ax, [startPoint(1) endPoint(1)], ...
            [startPoint(2) endPoint(2)], 'LineWidth', settings.LineWidth, ...
            'Color', color2plot(index, :));
    end
end
end


function color2plot = valuesToColors(values, CLim, colorMap, fallbackColor)
if numel(values) == 1 || all(values == values(1))
    color2plot = repmat(fallbackColor, numel(values), 1);
    return
end
scaled = (values - CLim(1)) ./ max(diff(CLim), eps);
scaled = max(0, min(1, scaled));
indices = round(scaled * (size(colorMap, 1) - 1)) + 1;
color2plot = colorMap(indices, :);
end


function h = drawDirectedLine(ax, startPoint, endPoint, color, lineWidth, coordScale)
vector = endPoint - startPoint;
distance = hypot(vector(1), vector(2));
if distance <= eps
    h = gobjects(1);
    return
end
unit = vector / distance;
trim = min(distance * 0.12, 15 * coordScale);
lineEnd = endPoint - unit * trim;
h = line(ax, [startPoint(1) lineEnd(1)], [startPoint(2) lineEnd(2)], ...
    'LineWidth', lineWidth, 'Color', color);

normal = [-unit(2), unit(1)];
arrowLength = max(min(distance / 3, 15 * coordScale), 10 * coordScale);
arrowWidth = arrowLength * 0.45;
tip = endPoint - unit * trim * 0.25;
base = tip - unit * arrowLength;
patch(ax, [tip(1), base(1) + normal(1) * arrowWidth, base(1) - normal(1) * arrowWidth], ...
    [tip(2), base(2) + normal(2) * arrowWidth, base(2) - normal(2) * arrowWidth], ...
    color, 'EdgeColor', 'none');
end


function cbars = CBar()
cbars = [0.8 0 0; 0.8 0.4 0; 0.8 0.8 0; 0.4 0.8 0.4; ...
    0 0.8 0.8; 0 0.4 0.8; 0 0 0.8];
cbars = lineInterp(cbars, 256, 8);
cbars = cbars(end:-1:1, :);
end


function cbar = lineInterp(baseMap, cnum, pernum)
pointCount = size(baseMap, 1);
pointsPerSegment = max(round(cnum / (pointCount - 1)), pernum);
cbar = zeros((pointCount - 1) * pointsPerSegment, 3);
cursor = 1;
for segmentIndex = 1:(pointCount - 1)
    segmentRows = cursor:(cursor + pointsPerSegment - 1);
    for colorIndex = 1:3
        cbar(segmentRows, colorIndex) = linspace(baseMap(segmentIndex, colorIndex), ...
            baseMap(segmentIndex + 1, colorIndex), pointsPerSegment);
    end
    cursor = cursor + pointsPerSegment;
end
if size(cbar, 1) > cnum
    cbar(round(end / 2), :) = [];
end
end

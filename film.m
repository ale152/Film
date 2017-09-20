function film(IMG,varargin)
% Quiver doesn't appear on manual frames

if nargin == 0
    IMG = load_images;
end

Set.fig = figure;
Set.dim = size(IMG);
Set.gamma = 1;
Set.keyboard = '0';
Set.clim = [0 1];
Set.control = 'auto';
Set.scale_col = false;
Set.colormap_id = 'gray';

Set.quiver_scale = 1;
Set.hquiver = [];
Set.himage = [];

Set.xl = [1 Set.dim(2)];
Set.yl = [1 Set.dim(1)];

% Is the image color or bw?
Set = is_color(Set);
Set.opticalflow = false;

% Set the time based on the length
if Set.N_im > 10
    Set.time = 1/24;
else
    Set.time = 0.3;
end

% Convert image to double
IMG = double(IMG);
% Normalise if it's [0 255] format
if max(IMG(:)) > 1
    IMG = IMG/255;
end

disp_commands;

run = true; Set.fid = 1;
while run
    % Start the timer
    tic
    
    try
        % Make sure the right figure is selected
        figure(Set.fig)
        set(Set.fig,'Name',sprintf('Frame %d/%d',Set.fid,Set.N_im))
        hold on
        drawnow nocallbacks
        
        % Show the right frame
        frame = pick_frame(IMG,Set);
        
        % Apply corrections
        if Set.gamma ~= 1
            mi = min(frame(:));
            ma = max(frame(:));
            frame = (frame-mi)/(ma-mi);
            frame = frame.^Set.gamma;
        end
        
        % Show the image
        if Set.bw
            if isempty(Set.himage)
                Set.himage = image(frame*64);
                colormap gray
            else
                Set.himage.CData = frame*64;
            end
        else
            if isempty(Set.himage)
                Set.himage = image(frame);
            else
                Set.himage.CData = frame;
            end
        end
        
        % Show the optical flow
        if Set.opticalflow
            if ~exist('flowLK')
                flowLK = opticalFlowLK;
            end
            if Set.bw
                bf = flowLK.estimateFlow(frame);
            else
                bf = flowLK.estimateFlow(rgb2gray(frame));
            end
            if isempty(Set.hquiver)
                Set.hquiver = quiver(bf.Vx,bf.Vy,Set.quiver_scale);
            else
                Set.hquiver.UData = bf.Vx;
                Set.hquiver.VData = bf.Vy;
            end
            
        end
        
        % Read command
        Set.keyboard = lower(get(Set.fig,'currentchar'));
        Set = parse_command(Set);
        
        % Draw the figure
        drawnow
        
        % Wait for the time
        while toc < Set.time
            continue
        end
        Set.fps = 1/toc;
        
        if strcmp(Set.control,'auto')
            if Set.fid < Set.N_im
                Set.fid = Set.fid+1;
            else
                Set.fid = 1;
            end
        else
            pause
        end
    catch ME
        figure_was_closed = {'MATLAB:hgbuiltins:object_creation:InvalidFigureArgHandle'};
        if ismember(ME.identifier,figure_was_closed)
            return
        else
            % Something went wrong, probably the figure was closed
            rethrow(ME)
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Set = is_color(Set)
% If the sequence has 4 or 2 dimensions, the answer is clear
if numel(Set.dim) == 4
    Set.bw = false;
    Set.N_im = Set.dim(4);
    return
elseif numel(Set.dim) == 2
    Set.bw = true;
    Set.N_im = 1;
    return
end

if numel(Set.dim) == 3
    if Set.dim(3) ~= 3
        Set.bw = true;
        Set.N_im = Set.dim(3);
        return
    else
        % Here there could be an ambiguity. Is it three bw frames or a single
        % color frame?
        answer = questdlg('Is that a color image or 3 b/w frames?', ...
            'Is the image color?', ...
            'One color image','Three b/w frames','One color image');
        if strcmp(answer,'One color image')
            Set.bw = false;
            Set.N_im = 1;
        else
            Set.bw = true;
            Set.N_im = 3;
        end
    end
end


function frame = pick_frame(IMG,Set)
if Set.bw
    if Set.N_im > 1
        frame = IMG(:,:,Set.fid);
    else
        frame = IMG(:,:);
    end
else
    if Set.N_im > 1
        frame = IMG(:,:,:,Set.fid);
    else
        frame = IMG(:,:,:);
    end
end


function Set = parse_command(Set)

% Apply previous commands

% Set axes
axis tight equal ij
xlim(Set.xl)
ylim(Set.yl)

set(gca,'units','normalized','position',[0 0 1 1],'visible','off')

% Parse new commands
switch Set.keyboard
    % Zoom in
    case 'z'
        disp 'Zoom in'
        [xi,yi] = ginput(1);
        xl = xlim; w = diff(xl);
        yl = ylim; h = diff(yl);
        Set.xl = [xi-w/4, xi+w/4];
        Set.yl = [yi-h/4, yi+h/4];
    % Zoom out
    case 'x'
        disp 'Zoom out'
        xl = xlim; w = diff(xl);
        yl = ylim; h = diff(yl);
        xi = mean(xl);
        yi = mean(yl);
        Set.xl = [xi-w, xi+w];
        Set.yl = [yi-h, yi+h];
    % Zoom all
    case 'a'
        disp 'Reset zoom'
        xlim auto
        ylim auto
        Set.xl = xlim;
        Set.yl = ylim;
    % Pan
    case 'p'
        disp 'Pan around'
        [xi,yi] = ginput(1);
        xl = xlim; w = diff(xl);
        yl = ylim; h = diff(yl);
        Set.xl = [xi-w/2, xi+w/2];
        Set.yl = [yi-h/2, yi+h/2];
    % Adjust time
    case '+'
        fprintf('Actual speed: %.1f fps\n',Set.fps)
        disp 'Increase speed'
        Set.time = Set.time*.75;
    case '-'
        fprintf('Actual speed: %.1f fps\n',Set.fps)
        disp 'Decrease speed'
        Set.time = Set.time/.75;
    % Gamma correction
    case 'g'
        disp 'Increment gamma'
        Set.gamma = Set.gamma*.75;
    case 'h'
        disp 'Decrease gamma'
        Set.gamma = Set.gamma/.75;
    case 's'
        disp 'Toggle scale colors'
        if Set.scale_col
            Set.scale_col = false;
            Set.himage.CDataMapping = 'direct';
        else
            Set.scale_col = true;
            Set.himage.CDataMapping = 'scaled';
        end
    % Change colormap
    case 'c'
        if strcmp(Set.colormap_id,'gray')
            set(Set.fig,'colormap',jet);
            Set.colormap_id = 'jet';
        else
            set(Set.fig,'colormap',gray);
            Set.colormap_id = 'gray';
        end
    % Frame control
    case 'm'
        if strcmp(Set.control,'manual')
            disp 'Automatic frame'
            Set.control = 'auto';
        else
            disp 'Manual frame'
            Set.control = 'manual';
        end
    case '.'
        Set.fid = Set.fid+1;
        fprintf('Next frame: %d\n',Set.fid)
    case ','
        Set.fid = Set.fid-1;
        fprintf('Previous frame: %d\n',Set.fid)
    case 'j'
        answer = inputdlg('Jumpt to frame:');
        try
            Set.fid = str2num(answer{1});
            if Set.fid > Set.N_im
                Set.fid = Set.N_im;
            elseif Set.fid < 1
                Set.fid = 1;
            end
        end
    case 'k'
        disp 'Keyboard'
        keyboard
    case 'o'
        disp 'Toggle optical flow'
        if Set.opticalflow
            Set.opticalflow = false;
            % Delete previous quiver
            delete(Set.hquiver)
            Set.hquiver = [];
        else
            Set.opticalflow = true;
        end
    case {'1' '2' '3' '4'}
        disp 'Set quiver scale'
        if ~isempty(Set.hquiver)
            Set.hquiver.AutoScaleFactor = str2double(Set.keyboard).^2;
        end

end

% Loop fid
if Set.fid < 1
    Set.fid = Set.N_im;
elseif Set.fid > Set.N_im
    Set.fid = 1;
end

% Reset option
Set.keyboard = '0';
set(Set.fig,'CurrentCharacter','0')

function disp_commands
disp 'z: zoom in the area selected'
disp 'x: zoom out'
disp 'a: reset zoom, show all'
disp 'p: pan'
disp '+: increase play speed'
disp '-: decrease play speed'
disp 'g: increase gamma correction'
disp 'h: decrease gamma correction'
disp 's: scale colors'
disp 'c: change colormap'
disp 'm: toggle manual frame control'    
disp '.: next frame'
disp ',: previous frame'
disp 'j: jump to frame'
disp 'k: keyboard'

function IMG = load_images
if ispref('film','default_folder')
    def_fld = getpref('film','default_folder');
else
    def_fld = pwd;
end

[FileName,PathName] = uigetfile(fullfile(def_fld,'*.*'),'Select files sequence...', ...
    'MultiSelect','on');

setpref('film','default_folder',PathName);

for fi = 1:numel(FileName)
    if fi == 1
        samp = imread(fullfile(PathName,FileName{1}));
        dim = size(samp);
        if numel(dim) == 2
            IMG = zeros(dim(1),dim(2),numel(FileName));
        else
            IMG = zeros(dim(1),dim(2),3,numel(FileName));
        end
    end
    
    if numel(dim) == 2
        IMG(:,:,fi) = imread(fullfile(PathName,FileName{fi}));
    else
        IMG(:,:,:,fi) = imread(fullfile(PathName,FileName{fi}));
    end
end


% 
% 
% vidReader = VideoReader('viptraffic.avi');
% db = zeros(120,160,3,15*8);
% i = 1;
% while hasFrame(vidReader)
%     disp(i)
%     frameRGB = readFrame(vidReader);
%     db(:,:,:,i) = frameRGB;
%     i=i+1;
% end

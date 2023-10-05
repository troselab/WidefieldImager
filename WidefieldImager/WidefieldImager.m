function varargout = WidefieldImager(varargin)
% WIDEFIELDIMAGER MATLAB code for WidefieldImager.fig
%      WIDEFIELDIMAGER, by itself, creates a new WIDEFIELDIMAGER or raises the existing
%      singleton*.
%
%      H = WIDEFIELDIMAGER returns the handle to a new WIDEFIELDIMAGER or the handle to
%      the existing singleton*.
%
%      WIDEFIELDIMAGER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in WIDEFIELDIMAGER.M with the given input arguments.
%
%      WIDEFIELDIMAGER('Property','Value',...) creates a new WIDEFIELDIMAGER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before WidefieldImager_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to WidefieldImager_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help WidefieldImager

% Last Modified by GUIDE v2.5 22-Aug-2020 13:43:44

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @WidefieldImager_OpeningFcn, ...
    'gui_OutputFcn',  @WidefieldImager_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before WidefieldImager is made visible.
function WidefieldImager_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to WidefieldImager (see VARARGIN)

% check if matlab is 2016b or newer
handles.output = hObject;
if datenum(version('-date')) < 736588 %check if matlab is 2016b or newer
    warning('Matlab version is older as 2016b. This code might break on earlier versions because of the "contains" function.')
end

% some variables
handles.daqName = 'Dev1'; %name of the national instruments DAQ board
handles.extraFrames = 5; %amount of frames where the light is switched off at the end of the recording. This helps to ensure proper alignment with analog data.
handles.minSize = 100; % minimum free disk space before producing a warning (in GB)
handles.serverPath = '\\your_server_path'; %data server path

%% initialize NI card
handles = RecordMode_Callback(handles.RecordMode, [], handles); %check recording mode to create correct ni object
guidata(handles.WidefieldImager, handles);

%% initialize camera and set handles
info = imaqhwinfo;
handles.vidName = [];
camCheck = contains(info.InstalledAdaptors, 'pcocameraadaptor');

if any(camCheck)
    handles.vidName = info.InstalledAdaptors{camCheck}; %PCO camera
else
    camCheck = contains(info.InstalledAdaptors, 'pmimaq_2022b'); %Prime95B
    if any(camCheck)
        handles.vidName = info.InstalledAdaptors{camCheck}; %PCO camera
    end
end
handles.vidObj = checkCamera(handles.vidName, handles); %get PCO video object
set(handles.vidObj, 'PreviewFullBitDepth', 'off')
% check for other cameras if PCO adaptor is unavailable.
if isempty(handles.vidObj)
    disp('PCO camera not available. Searching for other cameras.');
    handles.vidName = [];
    if length(info.InstalledAdaptors) == 1
        handles.vidName = info.InstalledAdaptors{1};
    elseif length(info.InstalledAdaptors) > 1 %multiple adaptors present, ask for selection
        out = listdlg('Name', 'Please select your camera', ...
            'SelectionMode','single','liststring',info.InstalledAdaptors,'listsize',[300 300]);
        if ~isempty(out)
            handles.vidName = info.InstalledAdaptors{out};
        end
    end
    handles.sBinning.Enable = 'off'; %this only works with PCO camera so disable for other cameras
end

if ~isempty(handles.vidName)
    fprintf('Using %s as current video adapter\n',handles.vidName);
    handles.vidObj = checkCamera(handles.vidName, handles); %get non-PCO video object
    set(handles.vidObj, 'PreviewFullBitDepth', 'off')
    if ~isempty(handles.vidObj)
        preview(handles.vidObj,handles.ImagePlot.Children); %start preview
        maxRange = floor(256*0.7); %limit intensity to 70% of dynamic range to avoid ceiling effects
        cMap = gray(maxRange); cMap(end+1:256,:) = repmat([1 0 0 ],256-maxRange,1);
        colormap(handles.ImagePlot,cMap);
    end
end

if isempty(handles.vidObj)
    warning('No camera found. Type "imaqhwinfo" to make sure your camera is porperly installed and running.')
end

if any(ismember(handles.driveSelect.String(:,1), 'g')) %start on G: drive by default
    handles.driveSelect.Value = find(ismember(handles.driveSelect.String(:,1), 'g'));
end

% set timer for calibration mode
handles.Calibration = []; %placeholder for calibration mode
CheckPath(handles); %Check for data path, reset date and trialcount

% UIWAIT makes WidefieldImager wait for user response (see UIRESUME)
% uiwait(handles.WidefieldImager);


% --- Outputs from this function are returned to the command line.
function varargout = WidefieldImager_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in WaitForTrigger.
function WaitForTrigger_Callback(hObject, eventdata, handles)
% hObject    handle to WaitForTrigger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of WaitForTrigger

if get(hObject, 'Value')
    set(hObject, 'String' , 'Wait for Trigger ON')
    set(hObject, 'BackgroundColor' , '[0 1 0]')
else
    set(hObject, 'String' , 'Wait for Trigger OFF')
    set(hObject, 'BackgroundColor' , '[1 0 0]')
end

% change status indicator
if handles.WaitForTrigger.Value && handles.SnapshotTaken %Waiting for trigger and snapshot taken
    handles.AcqusitionStatus.BackgroundColor = [0 1 0];
    handles.AcqusitionStatus.String = 'Waiting';
    handles.CurrentStatus.String = 'Waiting for trigger';
    AcquireData(handles.WidefieldImager); %set to acquisition mode
elseif handles.WaitForTrigger.Value && ~handles.SnapshotTaken %Waiting for trigger but no snapshot taken
    handles.AcqusitionStatus.Value = false;
    handles.AcqusitionStatus.BackgroundColor = [1 0 0];
    set(handles.AcqusitionStatus, 'String' , 'Inactive')
    handles.CurrentStatus.String = 'No snapshot taken';
    disp('Please press the TAKE SNAPSHOT button. Recording will only start when at least one snapshot is taken.')
elseif ~handles.WaitForTrigger.Value && handles.SnapshotTaken %Not waiting for trigger but snapshot is taken
    handles.AcqusitionStatus.Value = false;
    handles.AcqusitionStatus.BackgroundColor = [1 0 0];
    set(handles.AcqusitionStatus, 'String' , 'Inactive')
    handles.CurrentStatus.String = 'Snapshot taken';
elseif ~handles.WaitForTrigger.Value && ~handles.SnapshotTaken %Not waiting for trigger and no snapshot is taken
    handles.AcqusitionStatus.Value = false;
    handles.AcqusitionStatus.BackgroundColor = [1 0 0];
    set(handles.AcqusitionStatus, 'String' , 'Inactive')
    handles.CurrentStatus.String = 'Not ready';
end



function BaselineFrames_Callback(hObject, eventdata, handles)
% hObject    handle to BaselineFrames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of BaselineFrames as text
%        str2double(get(hObject,'String')) returns contents of BaselineFrames as a double


% --- Executes during object creation, after setting all properties.
function BaselineFrames_CreateFcn(hObject, eventdata, handles)
% hObject    handle to BaselineFrames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ChangeDataPath.
function ChangeDataPath_Callback(hObject, eventdata, handles)
% hObject    handle to ChangeDataPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.DataPath.String = uigetdir; %overwrites the complete file path for data storage with user selection

function DataPath_Callback(hObject, eventdata, handles)
% hObject    handle to DataPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of DataPath as text
%        str2double(get(hObject,'String')) returns contents of DataPath as a double


% --- Executes during object creation, after setting all properties.
function DataPath_CreateFcn(hObject, eventdata, handles)
% hObject    handle to DataPath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in CurrentStatus.
function CurrentStatus_Callback(hObject, eventdata, handles)
% hObject    handle to CurrentStatus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of CurrentStatus


function RecordingID_Callback(hObject, eventdata, handles)
% hObject    handle to RecordingID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of RecordingID as text
%        str2double(get(hObject,'String')) returns contents of RecordingID as a double


% --- Executes during object creation, after setting all properties.
function RecordingID_CreateFcn(hObject, eventdata, handles)
% hObject    handle to RecordingID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in AnimalID.
function AnimalID_Callback(hObject, eventdata, handles)
% hObject    handle to AnimalID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns AnimalID contents as cell array
%        contents{get(hObject,'Value')} returns selected item from AnimalID

CheckPath(handles);


% --- Executes during object creation, after setting all properties.
function AnimalID_CreateFcn(hObject, eventdata, handles)
% hObject    handle to AnimalID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in ExperimentType.
function ExperimentType_Callback(hObject, eventdata, handles)
% hObject    handle to ExperimentType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ExperimentType contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ExperimentType

CheckPath(handles);

% --- Executes during object creation, after setting all properties.
function ExperimentType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ExperimentType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in BlueLight.
function BlueLight_Callback(hObject, eventdata, handles)
% hObject    handle to BlueLight (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isempty(handles.dNIdevice)
    %     disp('LED control not available - NI device is missing')
    set(hObject, 'Value',false)
else
    if hObject.Value
        out = false(1,3); out(handles.lightMode.Value) = true; %indicator for NI channel
        outputSingleScan(handles.dNIdevice,out)
        if handles.lightMode.Value == 1
            hObject.BackgroundColor = [0 0 1];
            hObject.String = 'BLUE is ON';
        elseif handles.lightMode.Value == 2
            hObject.BackgroundColor = [.5 0 .5];
            hObject.String = 'VIOLET is ON';
        elseif handles.lightMode.Value == 3
            hObject.BackgroundColor = [.25 0 .75];
            hObject.String = 'MIXED stim is ON';
        end
    else
        outputSingleScan(handles.dNIdevice,false(1,3))
        hObject.BackgroundColor = zeros(1,3);
        hObject.String = 'LED OFF';
    end
end

% --- Executes on key press with focus on BlueLight and none of its controls.
function BlueLight_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to BlueLight (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in TakeSnapshot.
function TakeSnapshot_Callback(hObject, eventdata, handles)
% hObject    handle to TakeSnapshot (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if handles.vidObj == 0
    disp('Snapshot not available. Check if camera is connected and restart.')
else
    h = figure('Toolbar','none','Menubar','none','NumberTitle','off','Name','Snapshot'); %create figure to show snapshot
    snap = getsnapshot(handles.vidObj); %get snapshot from video object
    temp = ls(handles.path.base); %check if earlier snapshots exist
    temp(1,8)=' '; % make sure temp has enough characters
    temp = temp(sum(ismember(temp(:,1:8),'Snapshot'),2)==8,:); %only keep snapshot filenames
    temp(~ismember(temp,'0123456789')) = ' '; %replace non-integer characters with blanks
    cNr = max(str2num(temp)); %get highest snapshot nr
    cNr(isempty(cNr)) = 0; %replace empty with 0 if no previous snapshot existed
    save([handles.path.base 'Snapshot_' num2str(cNr+1) '.mat'],'snap') % snapshot
    imwrite(mat2gray(snap),[handles.path.base 'Snapshot_' num2str(cNr+1) '.jpg']) %save snapshot as jpg

    %     imshow(snap,'XData',[0 1],'YData',[0 1]); colormap gray; axis image;
    imshow(snap); axis image; title(['Saved as Snapshot ' num2str(cNr+1)]);
    uicontrol('String','Close','Callback','close(gcf)','units','normalized','position',[0 0 0.15 0.07]); %close button
    handles.SnapshotTaken = true; %update snapshot flag

    % change status indicator
    if handles.WaitForTrigger.Value %Waiting for trigger and snapshot taken
        handles.AcqusitionStatus.BackgroundColor = [0 1 0];
        handles.AcqusitionStatus.String = 'Waiting';
        handles.CurrentStatus.String = 'Waiting for trigger';
        AcquireData(handles.WidefieldImager); %set to acquisition mode

    elseif ~handles.WaitForTrigger.Value %Not waiting for trigger but snapshot is taken
        handles.AcqusitionStatus.Value = false;
        handles.AcqusitionStatus.BackgroundColor = [1 0 0];
        set(handles.AcqusitionStatus, 'String' , 'Inactive')
        handles.CurrentStatus.String = 'Snapshot taken';
    end
    guidata(hObject,handles);
end

% --- Executes on button press in StartPreview.
function StartPreview_Callback(hObject, eventdata, handles)
% hObject    handle to StartPreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if handles.vidObj == 0
    disp('Preview not available. Check if camera is connected and restart.')
else
    preview(handles.vidObj,handles.ImagePlot.Children); %start preview
    maxRange = floor(256*0.7); %limit intensity to 70% of dynamic range to avoid ceiling effects
    cMap = gray(maxRange); cMap(end+1:256,:) = repmat([1 0 0 ],256-maxRange,1);
    colormap(handles.ImagePlot,cMap);
end

% --- Executes on button press in StopPreview.
function StopPreview_Callback(hObject, eventdata, handles)
% hObject    handle to StopPreview (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~(handles.vidObj == 0)
    stoppreview(handles.vidObj); %stop preview
end

% --- Executes on button press in SelectROI.
function SelectROI_Callback(hObject, eventdata, handles)
% hObject    handle to SelectROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if handles.vidObj == 0
    disp('ROI change not available. Check if camera is connected and restart.')
else
    %% select ROI
    closepreview(handles.vidObj) %stop camera, and set new ROI position
    stop(handles.vidObj) %stop camera
    snap = getsnapshot(handles.vidObj);
    imshow(snap,'Parent',handles.ImagePlot);
    [~,ROI] = imcrop(handles.ImagePlot);
    ROI = floor(ROI);

    if ~isempty(ROI)
        handles.CurrentResolution.String = [num2str(ROI(3)) ' x ' num2str(ROI(4))]; %update current resolution indicator
        h = figure; %create temporary figure for saving the roi selection
        %         imshow(snap,'XData',[0 1],'YData',[0 1]); hold on %plot current view
        imshow(snap); hold on %plot current view
        xVals = [repmat(ROI(1),1,2) repmat(ROI(1)+ROI(3),1,2) ROI(1)];
        yVals = [ROI(2) repmat(ROI(2)+ROI(4),1,2) repmat(ROI(2),1,2)];
        plot(xVals,yVals,'r','linewidth',2) %plot ROI outline
        savefig(gcf,[handles.path.base 'ROI.fig']) %save ROI figure
        saveas(h,[handles.path.base 'ROI.jpg']) %save ROI as jpg
        close

        %update preview
        handles.ROIposition = ROI;
        set(handles.vidObj,'ROIposition',handles.ROIposition);
        snap = getsnapshot(handles.vidObj); hold(handles.ImagePlot,'off');
        %         imshow(snap,[],'parent',handles.ImagePlot,'XData',[0 1],'YData',[0 1]);
        imshow(snap,[],'parent',handles.ImagePlot);
    end

    maxRange = floor(256*0.7); %limit intensity to 70% of dynamic range to avoid ceiling effects
    cMap = gray(maxRange); cMap(end+1:256,:) = repmat([1 0 0 ],256-maxRange,1);
    colormap(handles.ImagePlot,cMap);
    preview(handles.vidObj,handles.ImagePlot.Children); %resume preview
end

% --- Executes on button press in ResetROI.
function ResetROI_Callback(hObject, eventdata, handles)
% hObject    handle to ResetROI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if handles.vidObj == 0
    disp('ROI change not available. Check if camera is connected and restart.')
else
    vidRes = get(handles.vidObj,'VideoResolution');
    handles.ROIposition = [0 0 vidRes];  %default ROIposition
    stoppreview(handles.vidObj) %stop camera
    stop(handles.vidObj) %stop camera
    set(handles.vidObj,'ROIposition',handles.ROIposition); % set new ROI position
    snap = getsnapshot(handles.vidObj); %get snapshot from video object
    %     imshow(snap,[],'parent',handles.ImagePlot,'XData',[0 1],'YData',[0 1]); hold(handles.ImagePlot,'off'); %plot current view
    imshow(snap,[],'parent',handles.ImagePlot); hold(handles.ImagePlot,'off'); %plot current view
    colormap(handles.ImagePlot,'gray');
    preview(handles.vidObj,handles.ImagePlot.Children); %resume preview
    maxRange = floor(256*0.7); %limit intensity to 70% of dynamic range to avoid ceiling effects
    cMap = gray(maxRange); cMap(end+1:256,:) = repmat([1 0 0 ],256-maxRange,1);
    colormap(handles.ImagePlot,cMap);

    % update current resolution in GUI
    imHeight = handles.ROIposition(3)-handles.ROIposition(1);
    imWidth = handles.ROIposition(4)-handles.ROIposition(2);
    handles.CurrentResolution.String = [num2str(imWidth) ' x ' num2str(imHeight)]; %update current resolution indicator
end

function CurrentResolution_Callback(hObject, eventdata, handles)
% hObject    handle to CurrentResolution (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of CurrentResolution as text
%        str2double(get(hObject,'String')) returns contents of CurrentResolution as a double

if handles.vidObj == 0
    disp('ROI change not available. Check if camera is connected and restart.')
else
    S = get(hObject,'String'); %get resolution string
    S(strfind(S,'x'):strfind(S,'x')+1)=[]; %remove 'x' from string
    nRes = str2num(S);
    vidRes = get(handles.vidObj,'VideoResolution');

    if length(nRes) == 2 && nRes(1)<=vidRes(2) && nRes(2)<=vidRes(1)
        handles.ROIposition =[0 0 nRes(1) nRes(2)];
        stop(handles.vidObj) %stop camera
        set(handles.vidObj,'ROIposition',handles.ROIposition); % set new ROI position
        colormap(handles.ImagePlot,'gray');
        preview(handles.vidObj)  %resume camera preview
        maxRange = floor(256*0.7); %limit intensity to 70% of dynamic range to avoid ceiling effects
        cMap = gray(maxRange); cMap(end+1:256,:) = repmat([1 0 0 ],256-maxRange,1);
        colormap(handles.ImagePlot,cMap);
    else
        disp([get(hObject,'String') ' is not a valid input to change the resolution'])
    end
end


% --- Executes during object creation, after setting all properties.
function CurrentResolution_CreateFcn(hObject, eventdata, handles)
% hObject    handle to CurrentResolution (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in AcqusitionStatus.
function AcqusitionStatus_Callback(hObject, eventdata, handles)
% hObject    handle to AcqusitionStatus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of AcqusitionStatus
if ~(get(handles.WaitForTrigger, 'value') && handles.SnapshotTaken)
    set(handles.AcqusitionStatus, 'value',false)
end

% --- Executes when user attempts to close IntrinsicImagerGUI.
function WidefieldImager_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to WidefieldImagerGUI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%% move saved files to data save location
sFiles = dir([handles.path.base '*Snapshot*']);
rFiles = dir([handles.path.base '*ROI*']);
aFiles = [{sFiles.name} {rFiles.name}];

if ~exist(get(handles.DataPath,'String'), 'dir') %create data path if not existent
    mkdir(get(handles.DataPath,'String'))
end
for iFiles = 1:length(aFiles)
    movefile([handles.path.base aFiles{iFiles}],[get(handles.DataPath,'String') filesep aFiles{iFiles}]); %move files
end

%% ensure calibration mode is off
handles.CalibrationMode.Value = false;
CalibrationMode_Callback(handles.CalibrationMode, [], handles); drawnow;

%% clear running objects
imaqreset
guidata(hObject,handles);
delete(hObject)

function AcquireData(hObject)
% function to acquire images from the camera when GUI is set to wait for
% trigger and a snapshot has been acquired
handles = guidata(hObject); %get handles

%% check for errors in trigger lines
data = false(1,3);
if ~isempty(handles.dNIdevice)
    data = inputSingleScan(handles.dNIdevice); %trigger lines
end
if sum(data) == length(data) %all triggers are active - leave acqusition mode and reset indicators
    disp('Acquire and stimulus triggers are both high - check if triggers are correctly connected and try again.')
    set(handles.WaitForTrigger, 'value' , false)
    set(handles.WaitForTrigger, 'String' , 'Wait for Trigger OFF')
    set(handles.WaitForTrigger, 'BackgroundColor' , '[1 0 0]')
    set(handles.AcqusitionStatus, 'value' , false)
    set(handles.AcqusitionStatus, 'String' , 'Inactive')
    set(handles.AcqusitionStatus, 'BackgroundColor' , '[1 0 0]')
    set(handles.AcqusitionStatus, 'String' , 'Inactive')
    handles.CurrentStatus.String = 'Snapshot taken';
    return
else
    %% ensure calibration mode is off
    handles.CalibrationMode.Value = false;
    CalibrationMode_Callback(handles.CalibrationMode, [], handles); drawnow;

    src = getselectedsource(handles.vidObj);
    if strcmpi(handles.vidName,'pcovideoadapter')
        src.E2ExposureTime = 1000/str2double(handles.FrameRate.String) * 1000; %make sure current framerate is used
        if str2double(handles.FrameRate.String) > 10 && strcmp(handles.sBinning.String(handles.sBinning.Value),'1')
            warning('FrameRate is above 10Hz at full resolution. This can lead to performance issues.')
        end
    end
    handles.BlueLight.Value = false; BlueLight_Callback(handles.BlueLight, [], handles) %switch LED off
    colormap(handles.ImagePlot,'jet');

    %%move saved files to actual data save location
    sFiles = dir([handles.path.base '*Snapshot*']);
    rFiles = dir([handles.path.base '*ROI*']);
    aFiles = [{sFiles.name} {rFiles.name}];

    if ~exist(get(handles.DataPath,'String'), 'dir') %create data path if not existent
        mkdir(get(handles.DataPath,'String'))
    end
    for iFiles = 1:length(aFiles)
        movefile([handles.path.base aFiles{iFiles}],[get(handles.DataPath,'String') filesep aFiles{iFiles}]); %move files
    end

    %save recorder handles to know all the settings later. Need to disable some warnings temporarily to avoid confusion.
    warning('off','MATLAB:Figure:FigureSavedToMATFile');
    warning('off','imaq:saveobj:recursive');
    save([handles.DataPath.String filesep 'handles.mat'],'handles')
    warning('on','MATLAB:Figure:FigureSavedToMATFile');
    warning('on','imaq:saveobj:recursive');

    % check if server location is available and create folder for behavioral data
    % 'open' indicates that this is the folder that relates to the current imaging session
    if exist(handles.serverPath,'dir')
        fPath = get(handles.DataPath,'string');
        fPath = strrep(fPath,fPath(1:2),handles.serverPath); %replace path of local drive with network drive
        fPath = [fPath '_open']; %add identifier that this session is currently being acquired (useful to point apps to the same folder)
        mkdir(fPath); %this is the server folder where other programs can write behavioral data.
    end

    %% start data acquisition
    stoppreview(handles.vidObj); %stop preview
    stop(handles.vidObj);
    flushdata(handles.vidObj);
    start(handles.vidObj); %get camera ready to be triggered
    StateCheck = true; %flag to control acquisition mode
    handles.lockGUI.Value = true; handles = lockGUI_Callback(handles.lockGUI, [], handles); %run callback for lock button

    % inactivate some parts of the GUI so they dont mess with the recording
    set(findall(handles.ExperimentID, '-property', 'enable'), 'enable', 'off')
    set(findall(handles.ControlPanel, '-property', 'enable'), 'enable', 'inactive')
    handles.FrameRate.Enable = 'off';
    handles.sBinning.Enable = 'off';
    handles.driveSelect.Enable = 'off';
    handles.ChangeDataPath.Enable = 'off';

    % automatically unlock software triggers if NI device is missing
    handles.triggerLock.Enable = 'on';
    if isempty(handles.dNIdevice)
        handles.triggerLock.Value = false;
        handles = triggerLock_Callback(handles.triggerLock, [], handles); %unlock software triggers
    end

    while StateCheck
        %% check if still recording here
        drawnow %update GUI inputs
        StateCheck = logical(get(handles.WaitForTrigger, 'value')); %check WaitForTrigger to determine whether acqusition should still be active

        if ~StateCheck %leave acqusition mode and reset indicators
            disp('Acqusition stopped');
            if exist('fPath','var')
                movefile(fPath,strrep(fPath, '_open', '')); %rename data folder on the server. Later, imaging data can be moved there using 'Widefield_MoveData'.
            end

            % lock software trigger buttons again
            handles.triggerLock.Value = true;
            handles = triggerLock_Callback(handles.triggerLock, [], handles); %unlock software triggers
            handles.triggerLock.Enable = 'off';

            set(handles.WaitForTrigger, 'String' , 'Wait for Trigger OFF')
            set(handles.WaitForTrigger, 'BackgroundColor' , '[1 0 0]')
            set(handles.AcqusitionStatus, 'value' , false)
            set(handles.AcqusitionStatus, 'String' , 'Inactive')
            set(handles.AcqusitionStatus, 'BackgroundColor' , '[1 0 0]')
            handles.CurrentStatus.String = 'Snapshot taken';
            set(findall(handles.ExperimentID, '-property', 'enable'), 'enable', 'on')
            set(findall(handles.ControlPanel, '-property', 'enable'), 'enable', 'on')
            handles.FrameRate.Enable = 'on';
            if contains(handles.vidName, 'pcocameraadaptor') || contains(handles.vidName, 'pmimaq_2022b')
                handles.sBinning.Enable = 'on';
            end
            handles.driveSelect.Enable = 'on';
            handles.ChangeDataPath.Enable = 'on';
            CheckPath(handles);

            % stop camera
            stop(handles.vidObj);
            flushdata(handles.vidObj);

            return
        end

        %% wait for trial trigger
        data = false(1,3);
        if ~isempty(handles.dNIdevice)
            data = inputSingleScan(handles.dNIdevice); %trigger lines
        end
        MaxWait = str2double(get(handles.WaitingTime,'String')); %get maximum waiting time.
        aTrigger = logical(data(1)); %trigger to start data acqusition
        if sum(data) == length(data)
            aTrigger = false; %do not initate if all triggers are high together (rarely happens due to noise in the recording).
        end

        %check trial trigger button
        if ~aTrigger
            aTrigger = handles.TrialTrigger.Value;
            handles.TrialTrigger.Value = false;
        end

        removedFrames = 0; %keep track of removed frames
        if aTrigger
            tic; %timer to abort acquisition if stimulus is not received within a certain time limit
            set(handles.TrialNr,'String',num2str(str2double(get(handles.TrialNr,'String'))+1)); %increase TrialNr;

            set(handles.CurrentStatus,'String','Recording baseline'); %update status indicator
            set(handles.AcqusitionStatus, 'value', true); %set acquisition status to active
            set(handles.AcqusitionStatus, 'String' , 'Recording')
            handles.BlueLight.Value = true; BlueLight_Callback(handles.BlueLight, [], handles) %switch LED on
            handles.lockGUI.Value = true; handles = lockGUI_Callback(handles.lockGUI, [], handles); %run callback for lock button
            drawnow;

            if ~isempty(handles.dNIdevice)
                aID = fopen([get(handles.DataPath,'String') filesep 'Analog_' get(handles.TrialNr,'String') '.dat'], 'wb'); %open binary file for analog data
                handles.aListen = addlistener(handles.aNIdevice,'DataAvailable', @(src, event)logAnalogData(src,event,aID,handles.AcqusitionStatus)); %listener to stream analog data to disc
                handles.aNIdevice.startBackground(); %start analog data streaming
            end

            if contains(handles.vidName, 'pcocameraadaptor')
                frameRate = str2double(handles.FrameRate.String);
            elseif contains(handles.vidName, 'pmimaq_2022b')
                frameRate = str2double(handles.FrameRate.String);
            else
                frameRate = str2double(handles.FrameRate.String{handles.FrameRate.Value});
            end
            bSize = ceil(str2double(handles.BaselineFrames.String)*frameRate); %number of frames in baseline
            sSize = ceil(str2double(handles.PostStimFrames.String)*frameRate); %number of frames after stimulus trigger

            pause(0.2); %make sure light and analog streaming are on before triggering the camera
            handles.vidObj.FramesPerTrigger = Inf; %acquire until stoppped
            trigger(handles.vidObj); %start image acquisition

            while handles.AcqusitionStatus.Value %keep running until poststim data is recorded
                if ~isempty(handles.dNIdevice)
                    data = inputSingleScan(handles.dNIdevice); %trigger lines
                else
                    data = false(1,3);
                end
                if sum(data) == length(data)
                    stimTrigger = false; %do not proceed if all triggers are high
                else
                    stimTrigger = logical(data(2)); %trigger that indicates start of stimulus presentation
                    stopTrigger = logical(data(3)); %trigger that indicates end of trial. aborts frame acquisition of read before all poststim frames have been collected.

                    %check buttons
                    if ~stimTrigger
                        drawnow;
                        stimTrigger = handles.StimTrigger.Value;
                        handles.StimTrigger.Value = false;
                    end
                    if ~stopTrigger
                        drawnow;
                        stopTrigger = handles.StopTrigger.Value;
                        handles.StopTrigger.Value = false;
                    end
                end

                if ~stimTrigger && (toc < MaxWait) && ~stopTrigger %record baseline frames until stimulus trigger occurs or maximum waiting time is reached
                    if handles.vidObj.FramesAvailable > bSize*2
                        [~,rejFrames] = getdata(handles.vidObj,bSize); %remove unnecessary frames from video capture stream
                        disp(['Waiting... Removing ' num2str(length(rejFrames)) ' frames from buffer']);
                        removedFrames = removedFrames + length(rejFrames); %count removed frames
                    end
                else
                    bIdx = handles.vidObj.FramesAvailable; %check available baseline frames
                    if toc < MaxWait && ~stopTrigger %record poststim if stimulus trigger was received
                        set(handles.CurrentStatus,'String','Recording PostStim');drawnow;
                        FrameWait = true;
                        while FrameWait %wait until post-stim frames are captured
                            FrameWait = handles.vidObj.FramesAvailable < (bIdx+sSize); %stop condition
                            if ~isempty(handles.dNIdevice)
                                data = inputSingleScan(handles.dNIdevice); %hardware trigger lines
                                stopTrigger = logical(data(3));
                            else
                                data = false(1,3);
                                stopTrigger = false;
                            end

                            %check stop button
                            if ~stopTrigger
                                drawnow;
                                stopTrigger = handles.StopTrigger.Value;
                                handles.StopTrigger.Value = false;
                            end

                            if sum(data) ~= length(data)
                                if stopTrigger %trigger that indicates if end of trial has been reached
                                    FrameWait = false;
                                    disp(['Received stop trigger. Stopped after ' num2str(handles.vidObj.FramesAvailable-bIdx) ' poststim frames']);
                                end
                            end
                        end
                    elseif stopTrigger
                        disp('Received stop trigger. No poststim data recorded'); drawnow;
                    else
                        disp('Maximum waiting time reached. No poststim data recorded'); drawnow;
                    end

                    % switch off LED and grab some extra dark frames to ensure that blue and violet channels can be separated correctly.
                    recPause = (handles.extraFrames + 1) / str2double(handles.FrameRate.String); %pause long enough to get extra frames.
                    if recPause < 0.2; recPause = 0.2; end %at least 200ms pause

                    handles.BlueLight.Value = false; BlueLight_Callback(handles.BlueLight, [], handles) %switch LED off

                    if ~isempty(handles.dNIdevice)
                        pause(recPause); handles.aNIdevice.stop(); %pause to ensure all analog data is written, then stop analog object
                        fclose(aID); %close analog data file
                        delete(handles.aListen); %delete listener for analog data recording
                    end
                    stop(handles.vidObj); %stop video capture

                    if (bIdx-bSize) > 0
                        [~, rejFrames] = getdata(handles.vidObj,bIdx-bSize); %remove unnecessary frames from video object
                        disp(['Trial finished... Removing ' num2str(length(rejFrames)) ' frames from buffer']);
                        removedFrames = removedFrames + length(rejFrames); %count removed frames
                    end

                    if handles.vidObj.FramesAvailable < (bSize + sSize + handles.extraFrames)
                        [Data,~,frameTimes] = getdata(handles.vidObj, handles.vidObj.FramesAvailable); %collect available video data
                    else
                        [Data,~,frameTimes] = getdata(handles.vidObj, bSize + sSize + handles.extraFrames); %collect requested video data
                    end
                    frameTimes = datenum(cat(1,frameTimes(:).AbsTime)); %collect absolute timestamps

                    if bIdx < bSize %if baseline has less frames as set in the GUI
                        disp(['Collected only ' num2str(bIdx) ' instead of ' num2str(bSize) ' frames in the baseline. Not enough time between trial and stimulus trigger.'])
                    else
                        bIdx = bSize;
                    end
                    set(handles.AcqusitionStatus, 'value', false); %stop recording
                    set(handles.AcqusitionStatus, 'String' , 'Waiting')

                end
            end

            %% Save data to folder and clear
            preStim = bIdx; %number of prestim frames
            postStim = size(Data,4)-bIdx; %number of poststim frames

            set(handles.CurrentStatus,'String','Saving data');
            disp(['Trial ' get(handles.TrialNr,'String') '; Baseline Frames: ' num2str(preStim) '; Poststim Frames: ' num2str(postStim) '; Dark Frames: ' num2str(handles.extraFrames) '; Saving data ...'])

            % save frametimes and size of widefield data (this is useful to read binary data later)
            imgSize = size(Data);
            cFile = ([get(handles.DataPath,'String') filesep 'frameTimes_' num2str(str2double(handles.TrialNr.String), '%04i') '.mat']);
            save(cFile, 'frameTimes', 'imgSize', 'removedFrames', 'preStim', 'postStim'); %save frametimes

            numChans = 1 + (handles.lightMode.Value == 3); %two channels if lightmode is set to 'mixed'

            cFile = sprintf('%s%cFrames_%d_%d_%d_%s_%s', get(handles.DataPath,'String'), ...
                filesep, numChans, size(Data,2), size(Data,1), class(Data), num2str(str2double(handles.TrialNr.String), '%04i')); %name for imaging data file

            if ~handles.saveTIF.Value %saw as raw binary (default because of high writing speed)
                sID = fopen([cFile '.dat'], 'Wb'); %open binary stimulus file
                fwrite(sID,Data,'uint16'); %write iamging data as flat binary
                fclose(sID);

            else %save as tiff stack (writes slower but raw data is more accessible)
                for x = 1 : imgSize(end)
                    if length(imgSize) == 3
                        imwrite(Data(:, :, x), [cFile '.tif'], 'WriteMode', 'append', 'Compression', 'none');
                    elseif length(imgSize) == 4
                        imwrite(Data(:, :, :, x), [cFile '.tif'], 'WriteMode', 'append', 'Compression', 'none');
                    end
                end
            end

            % show average of current trial
            baselineAvg = squeeze(mean(Data(:,:,1,1:bIdx),4));
            stimAvg = squeeze(mean(Data(:,:,1,bIdx+1:end),4));
            stimAvg = (stimAvg-baselineAvg)./baselineAvg;
            imshow(mat2gray(stimAvg),'parent',handles.ImagePlot);
            colormap(handles.ImagePlot, parula(256));
            drawnow;
            clear Data frameTimes

            disp(['Trial ' handles.TrialNr.String ' completed.']); toc;
            disp('==================================================');

            start(handles.vidObj); %get camera ready to be triggered again
            set(handles.CurrentStatus,'String','Waiting for trigger');
            handles.lockGUI.Value = false; handles = lockGUI_Callback(handles.lockGUI, [], handles); %run callback for lock button

        end
    end
end



function PostStimFrames_Callback(hObject, eventdata, handles)
% hObject    handle to PostStimFrames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of PostStimFrames as text
%        str2double(get(hObject,'String')) returns contents of PostStimFrames as a double


% --- Executes during object creation, after setting all properties.
function PostStimFrames_CreateFcn(hObject, eventdata, handles)
% hObject    handle to PostStimFrames (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function TrialNr_Callback(hObject, eventdata, handles)
% hObject    handle to TrialNr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of TrialNr as text
%        str2double(get(hObject,'String')) returns contents of TrialNr as a double


% --- Executes during object creation, after setting all properties.
function TrialNr_CreateFcn(hObject, eventdata, handles)
% hObject    handle to TrialNr (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function handles = CheckPath(handles)

% Look for single-letter drives, starting at a: or c: as appropriate
try
    if ispc
        ret = {};
        for i = double('c') : double('z')
            if exist(['' i ':' filesep], 'dir') == 7
                ret{end+1} = [i ':']; %#ok<AGROW>
            end
        end

    elseif ismac
        ret = dir('/Volumes/');
        ret = {ret(3:end).name};
    end
    handles.driveSelect.String = char(ret);
end

cPath = java.io.File(strtrim(handles.driveSelect.String(handles.driveSelect.Value,:))); %make sure this is OS independent
if (cPath.getFreeSpace / 2^30) < handles.minSize && length(handles.driveSelect.String) > 1 && cPath.getFreeSpace > 0
    answer = questdlg(['Only ' num2str((cPath.getFreeSpace / 2^30)) 'gb left on ' strtrim(handles.driveSelect.String(handles.driveSelect.Value,:)) filesep '. Change drive?'], ...
        'Drive select', 'Yes', 'No', 'No, stop asking me', 'Yes');
    if strcmp(answer, 'Yes')
        checker = true;
        cDrive = handles.driveSelect.Value; %keep current drive index
        while checker
            handles.driveSelect.Value = rem(handles.driveSelect.Value,length(handles.driveSelect.String))+1; %increase drive selection value by 1
            cPath = java.io.File(strtrim(handles.driveSelect.String(handles.driveSelect.Value,:)));
            if (cPath.getFreeSpace / 2^30) > handles.minSize
                disp(['Changed path to drive ' strtrim(handles.driveSelect.String(handles.driveSelect.Value,:)) filesep '. ' num2str((cPath.getFreeSpace / 2^30)) 'gb remaining.'])
                checker = false;
            elseif handles.driveSelect.Value == cDrive
                disp(['Could not find a drive with more then ' num2str(handles.minSize) 'gb of free space. Path unchanged.'])
                checker = false;
            end
        end
    elseif strcmp(answer, 'No, stop asking me')
        handles.minSize = 0; %don't check disk size anymore
    end
end

% set basepath and look for present animals, experiment types and past recordings
handles.path.base = [char(cPath) filesep ...
    strtrim(handles.RecordMode.String{handles.RecordMode.Value}) filesep]; %set path of imaging code

if ~exist([handles.path.base 'Animals'],'dir') %check for animal path to save data
    mkdir([handles.path.base 'Animals']) %create folder if required
end

handles.AnimalID.String = cellstr(handles.AnimalID.String);
folders = dir([handles.path.base 'Animals']); %find animal folders
folders = folders([folders.isdir] & ~strncmpi('.', {folders.name}, 1));
checker = true;
for iAnimals = 1:size(folders,1) %skip first two entries because they contain folders '.' and '..'
    AllAnimals{iAnimals} = folders(iAnimals).name; %get animal folders
    if checker
        if strcmp(handles.AnimalID.String{handles.AnimalID.Value},folders(iAnimals).name) %check if current selected animal coincides with discovered folder
            handles.AnimalID.Value = iAnimals; %keep animal selection constant
            checker = false;
        end
    end
end

if isempty(iAnimals) %Check if any animals are found
    AllAnimals{1} = 'Dummy Subject'; %create dummy animal if nothing else is found
    mkdir([handles.path.base 'Animals' filesep 'Dummy Subject']) %create folder for default experiment
end

handles.AnimalID.String = AllAnimals; %update AnimalID selection
if handles.AnimalID.Value > length(AllAnimals)
    handles.AnimalID.Value = 1; %reset indicator
end
if ~isempty(handles.AnimalID.Value)
    handles.path.AnimalID = AllAnimals{handles.AnimalID.Value}; %update path for current animal
end

folders = dir([handles.path.base 'Animals' filesep AllAnimals{handles.AnimalID.Value}]); %find Experiment folders
folders = folders([folders.isdir] & ~strncmpi('.', {folders.name}, 1));
for iExperiments = 1:size(folders,1) %skip first two entries because they contain folders '.' and '..'
    AllExperiments{iExperiments} = folders(iExperiments).name; %get experiment folders
end
if isempty(iExperiments) %Check if any experiments are found
    AllExperiments{1} = 'Default'; %create default experiment if nothing else is found
    mkdir([handles.path.base 'Animals' filesep AllAnimals{1} filesep 'Default']) %create folder for default experiment
end

handles.ExperimentType.String = AllExperiments; %update experiment type selection
if size(AllExperiments,2) < handles.ExperimentType.Value; handles.ExperimentType.Value = 1; end
handles.path.ExpType = AllExperiments{handles.ExperimentType.Value}; %update path for current experiment type
cPath = [handles.path.base 'Animals' filesep AllAnimals{handles.AnimalID.Value} filesep AllExperiments{handles.ExperimentType.Value}]; %assign current path

if exist([cPath filesep date], 'dir') && length(dir([cPath filesep date])) > 2 %check if folder for current date exist already and contains data
    Cnt = 1;
    while exist([cPath filesep date '_' num2str(Cnt)],'dir')
        Cnt = Cnt +1; %update counter until it is ensured that current experiment name is not used already
    end
    handles.path.RecordingID = [date '_' num2str(Cnt)]; %set folder for recording day as the date + neccesarry counter
else
    handles.path.RecordingID = date; %set folder for current recording to recording date
end
handles.RecordingID.String = handles.path.RecordingID; %update GUI
handles.DataPath.String = [cPath filesep handles.path.RecordingID]; %set complete file path for data storage
set(handles.TrialNr,'String','0'); %reset TrialNr
handles.SnapshotTaken = false; %flag for snapshot - has to be taken in order to start data acquisition
handles.CurrentStatus.String = 'Not ready'; %reset status indicator
guidata(handles.WidefieldImager, handles);


function WaitingTime_Callback(hObject, eventdata, handles)
% hObject    handle to WaitingTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of WaitingTime as text
%        str2double(get(hObject,'String')) returns contents of WaitingTime as a double


% --- Executes during object creation, after setting all properties.
function WaitingTime_CreateFcn(hObject, eventdata, handles)
% hObject    handle to WaitingTime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function logAnalogData(src, evt, fid, flag)
% Add the time stamp and the data values to data. To write data sequentially,
% transpose the matrix.
% Modified to use an additional flag to stop ongoing data acquistion if
% false. Flag should be a handle to a control that contains a logical
% value.
%
% Example for addding function to a listener when running analog through StartBackground:
% handles.aListen = handles.aNIdevice.addlistener('DataAvailable', @(src, event)logAnalogData(src,event,aID,handles.AcqusitionStatus)); %listener to stream analog data to disc


if src.IsRunning %only execute while acquisition is still active
    if evt.TimeStamps(1) == 0
        fwrite(fid,3,'double'); %indicate number of single values in the header
        fwrite(fid,evt.TriggerTime,'double'); %write time of acquisition onset on first run
        fwrite(fid,size(evt.Data,2)+1,'double'); %write number of recorded analog channels + timestamps
        fwrite(fid,inf,'double'); %write number of values to read (set to inf since absolute recording duration is unknown at this point)
    end

    data = [evt.TimeStamps*1000, evt.Data*1000]' ; %convert time to ms and voltage to mV
    fwrite(fid,uint16(data),'uint16');
    %     plot(data(1,:),data(2:end,:))

    if ~logical(get(flag, 'value')) %check if acqusition is still active
        src.stop(); %stop recording
    end
end


% --- Executes on selection change in lightMode.
function lightMode_Callback(hObject, eventdata, handles)
% hObject    handle to lightMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns lightMode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from lightMode

BlueLight_Callback(handles.BlueLight, [], handles) %switch LED


% --- Executes during object creation, after setting all properties.
function lightMode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to lightMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in NewAnimal.
function NewAnimal_Callback(hObject, eventdata, handles)
% hObject    handle to NewAnimal (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles = CheckPath(handles); %Check for data path, reset date and trialcount
dPrompt = {'Enter animal ID'};
pName = 'New animal';
newMouse = inputdlg(dPrompt,pName,1,{'New mouse'});
if ~isempty(newMouse)
    mkdir([handles.path.base 'Animals' filesep newMouse{1}])

    dPrompt = {'Enter experiment ID'};
    pName = 'New experiment';

    newExp = inputdlg(dPrompt,pName,1,{[strtrim(handles.RecordMode.String{handles.RecordMode.Value}) 'Paradigm']});
    mkdir([handles.path.base 'Animals' filesep newMouse{1} filesep newExp{1}])

    handles = CheckPath(handles); %Check for data path, reset date and trialcount
    handles.AnimalID.Value = find(ismember(handles.AnimalID.String,newMouse{1}));
    CheckPath(handles);
end

% --- Executes on button press in NewExperiment.
function NewExperiment_Callback(hObject, eventdata, handles)
% hObject    handle to NewExperiment (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

dPrompt = {'Enter experiment ID'};
pName = 'New experiment';
newExp = inputdlg(dPrompt,pName,1,{'New experiment'});
if ~isempty(newExp)
    mkdir([handles.path.base 'Animals' filesep handles.AnimalID.String{handles.AnimalID.Value} filesep newExp{1}])

    handles = CheckPath(handles); %Check for data path, reset date and trialcount
    handles.ExperimentType.Value = find(ismember(handles.ExperimentType.String,newExp{1}));
    CheckPath(handles);
end

function FrameRate_Callback(hObject, eventdata, handles)
% hObject    handle to FrameRate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of FrameRate as text
%        str2double(get(hObject,'String')) returns contents of FrameRate as a double

if ~isempty(handles.vidObj)
    stop(handles.vidObj);
    flushdata(handles.vidObj);
    src = getselectedsource(handles.vidObj);
    if contains(handles.vidName, 'pcocameraadaptor')
        if str2double(handles.FrameRate.String) > 10 && strcmp(handles.sBinning.String(handles.sBinning.Value),'1')
            answer = questdlg('Spatial binning is set to 1. This could produce a lot of data. Proceed?');
            if strcmpi(answer,'Yes')
                src.E2ExposureTime = 1000/str2double(handles.FrameRate.String) * 1000; %set current framerate
            end
        else
            src.E2ExposureTime = 1000/str2double(handles.FrameRate.String) * 1000; %set current framerate
        end
    elseif contains(handles.vidName, 'pmimaq_2022b')
        src.Exposure = 1000/str2double(handles.FrameRate.String) ; %set framerate
    else
        % Adjust frame rate for non-PCO camera.
        % !! Warning !! This does not take effect with all imaq video adaptors.
        % Make sure that your camera allows the Matlab adaptor to control the framerate.
        src.FrameRate = hObject.String{hObject.Value};
    end
end

% --- Executes during object creation, after setting all properties.
function FrameRate_CreateFcn(hObject, eventdata, handles)
% hObject    handle to FrameRate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit11_Callback(hObject, eventdata, handles)
% hObject    handle to edit11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit11 as text
%        str2double(get(hObject,'String')) returns contents of edit11 as a double


% --- Executes during object creation, after setting all properties.
function edit11_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in sBinning.
function sBinning_Callback(hObject, eventdata, handles)
% hObject    handle to sBinning (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns sBinning contents as cell array
%        contents{get(hObject,'Value')} returns selected item from sBinning

if contains(handles.vidName, 'pcocameraadaptor')
    src = getselectedsource(handles.vidObj);
    if str2double(handles.FrameRate.String) > 10 && strcmp(hObject.String(hObject.Value),'1')
        src.E2ExposureTime = 100000; %limit framerate to 10Hz
        disp('FrameRate is limited to 10Hz without spatial binning.')
    else
        src.E2ExposureTime = 1000/str2double(handles.FrameRate.String)*1000; %make sure current framerate is used
    end

    binFact = str2num(hObject.String(hObject.Value));
    try %uses different string in different adaptor versions...
        src.B1BinningHorizontal = num2str(binFact);
        src.B2BinningVertical = num2str(binFact);
    catch
        src.B1BinningHorizontal = num2str(binFact,'%02i');
        src.B2BinningVertical = num2str(binFact,'%02i');
    end

    vidRes = get(handles.vidObj,'VideoResolution');
    handles.CurrentResolution.String = [num2str(vidRes(1)) ' x ' num2str(vidRes(2))]; %update current resolution indicator
elseif contains(handles.vidName, 'pmimaq_2022b')
    if str2double(handles.FrameRate.String) > 10 && strcmp(hObject.String(hObject.Value),'1')
        src.Binning = "1x1";
        src.Exposure = 100; %limit framerate to 10Hz
        disp('FrameRate is limited to 10Hz without spatial binning.')
        binFact = 1;
    elseif strcmp(hObject.String(hObject.Value),'2')
        src.Binning = "2x2";
        binFact = 2;
    else
        disp('Unsupported Binning factor selected. Defaulting to 2x2')
        src.Binning = "2x2";
        binFact = 2;
        vidRes = get(handles.vidObj,'VideoResolution') ;
        handles.CurrentResolution.String = [num2str(vidRes(1)) ' x ' num2str(vidRes(2))]; %update current resolution indicator

    end
end

% --- Executes during object creation, after setting all properties.
function sBinning_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sBinning (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in RecordMode.
function handles = RecordMode_Callback(hObject, eventdata, handles)
% hObject    handle to RecordMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns RecordMode contents as cell array
%        contents{get(hObject,'Value')} returns selected item from RecordMode

handles.ExperimentType.Value = 1;
handles.AnimalID.Value = 1;

if hObject.Value == 1 %set standard settings for widefield mapping
    handles.BaselineFrames.String = '2';
    handles.PostStimFrames.String = '23';
elseif  hObject.Value == 2 %set standard settings for behavioral recording
    handles.BaselineFrames.String = '3';
    handles.PostStimFrames.String = '6';
end
handles = CheckPath(handles);

% check NI card
try
    daqs = daq.getDevices;
catch
    daqs = [];
end

if isempty(daqs)
    disp('No NI devices found or data acquisition toolbox missing.')
    disp('Use software triggers instead.')
    handles.dNIdevice = [];
else
    if isfield(handles,'dNIdevice')
        delete(handles.dNIdevice);
        delete(handles.aNIdevice);
    end

    checker = false; %check if daq device with correct ID is present. Default is 'Dev1'
    for x = 1 : length(daqs)
        if strcmpi(daqs(x).ID,handles.daqName)
            checker = true;
        end
    end
    if ~checker
        warning(['Could not find specified DAQ: ' handles.daqName ' - Using existing board ' daqs(x).ID ' instead.'])
        handles.daqName = daqs(x).ID;
    end

    handles.dNIdevice = daq.createSession(daqs(x).Vendor.ID); %object for communication with DAQ - digital lines
    handles.aNIdevice = daq.createSession(daqs(x).Vendor.ID); %object for communication with DAQ - analog lines
    handles.aNIdevice.IsContinuous = true; %set to continous acquisition
    handles.aNIdevice.Rate = 1000; %set sampling rate to 1kHz

    addDigitalChannel(handles.dNIdevice,handles.daqName,'port1/line0:2','OutputOnly'); %output channels for blue, violet and mixed light (1.0:blue, 1.1:violet, 1.2:mixed)
    outputSingleScan(handles.dNIdevice,false(1,3)); %make sure outputs are false
    addDigitalChannel(handles.dNIdevice,handles.daqName,'port0/line0:2','InputOnly'); %input channels to trigger data acquisition and control timing of animal behavior (0.2: trial start, 0.3: stim on)

    ch = addAnalogInputChannel(handles.aNIdevice,handles.daqName, 0:3, 'Voltage');
    for x = 1 : length(ch)
        ch(x).TerminalConfig = 'SingleEnded'; %use single-ended recordings. Use differential when recording low SNR signals (needs to line for +/-)
    end
end
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function RecordMode_CreateFcn(hObject, eventdata, handles)
% hObject    handle to RecordMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in driveSelect.
function driveSelect_Callback(hObject, eventdata, handles)
% hObject    handle to driveSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns driveSelect contents as cell array
%        contents{get(hObject,'Value')} returns selected item from driveSelect

a = strfind(handles.DataPath.String,filesep);
cPath = [strtrim(handles.driveSelect.String(handles.driveSelect.Value,:)) fileparts(handles.DataPath.String(a(1):end))];
if ~exist(cPath,'dir')
    mkdir(cPath);
end
handles = CheckPath(handles); %Check for data path, reset date and trialcount
guidata(handles.WidefieldImager, handles);

% --- Executes during object creation, after setting all properties.
function driveSelect_CreateFcn(hObject, eventdata, handles)
% hObject    handle to driveSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in lockGUI.
function handles = lockGUI_Callback(hObject, eventdata, handles)
% hObject    handle to lockGUI (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if islogging(handles.vidObj)
    hObject.Value = true;
    handles.WaitForTrigger.Enable = 'off';
    hObject.String = 'Locked';
    disp('Cant release recording control while acquiring data. Wait until trial is completed.')
else
    if hObject.Value == 0
        handles.WaitForTrigger.Enable = 'on';
        hObject.String = 'Released';
    elseif hObject.Value == 1
        handles.WaitForTrigger.Enable = 'off';
        hObject.String = 'Locked';
    end
end

% function to check camera settings
function vidObj = checkCamera(adaptorName, handles)
% check videoadapter, set settings from the GUI and start video preview.
% Returns an empty object if 'adaptorname' is not available.
vidObj = [];
binFact = 1;
try
    imaqreset
    vidObj = videoinput(adaptorName); %get video object
    src = getselectedsource(vidObj);
    set(vidObj, 'PreviewFullBitDepth', 'off')

    if contains(adaptorName, 'pcocameraadaptor') %check for PCO camera and set specific settings
        clockSpeed = set(src,'PCPixelclock_Hz');
        [~,idx] = max(cellfun(@str2num,clockSpeed)); %get fastest clockspeed
        src.PCPixelclock_Hz = clockSpeed{idx}; %fast scanning mode
        src.E2ExposureTime = 1000/str2double(handles.FrameRate.String) * 1000; %set framerate
        binFact = 4; %set 4x binning by default

        try %uses different string in different adaptor versions...
            src.B1BinningHorizontal = num2str(binFact);
            src.B2BinningVertical = num2str(binFact);
        catch
            src.B1BinningHorizontal = num2str(binFact,'%02i');
            src.B2BinningVertical = num2str(binFact,'%02i');
        end
    elseif contains(adaptorName, 'pmimaq_2022b')
        src.Binning = "2x2";
        binFact = 2;
        src.Exposure = 1000/str2double(handles.FrameRate.String) ; %set framerate
        src.FanSpeed = "Medium";
        src.ClearCycles = 0;
    else
        try
            handles.FrameRate.Style = 'popupmenu'; %change menu style to indicate available frame rates
            handles.FrameRate.String = set(src, 'FrameRate');
            src.FrameRate = handles.FrameRate.String{1}; %use highest available frame rate
        catch
            handles.FrameRate.String = {'40'};
        end
    end

    %setup and display live video feed in preview window
    vidRes = get(vidObj,'VideoResolution');
    nbands = get(vidObj,'NumberOfBands');
    handles.CurrentResolution.String = [num2str(vidRes(1)) ' x ' num2str(vidRes(2))]; %update current resolution indicator
    %     imshow(zeros(vidRes(2),vidRes(1),nbands),[],'parent',handles.ImagePlot,'XData',[0 1],'YData',[0 1]); %create image object for preview
    imshow(zeros(vidRes(2),vidRes(1),nbands),[],'parent',handles.ImagePlot); %create image object for preview

    %set default camera configuration
    handles.ROIposition = [0 0 vidRes];  %default ROIposition
    set(vidObj,'TriggerFrameDelay',0);
    set(vidObj,'FrameGrabInterval',1);
    set(vidObj,'TriggerRepeat',0);
    set(vidObj,'ROIposition',handles.ROIposition);
    set(vidObj,'FramesPerTrigger',Inf);
    triggerconfig(vidObj,'manual');

catch
    vidObj = [];
end


% --- Executes on button press in TrialTrigger.
function TrialTrigger_Callback(hObject, eventdata, handles)
% hObject    handle to TrialTrigger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in StimTrigger.
function StimTrigger_Callback(hObject, eventdata, handles)
% hObject    handle to StimTrigger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in StopTrigger.
function StopTrigger_Callback(hObject, eventdata, handles)
% hObject    handle to StopTrigger (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in triggerLock.
function handles = triggerLock_Callback (hObject, eventdata, handles)
% hObject    handle to triggerLock (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of triggerLock

handles.TrialTrigger.Value = false;
handles.StimTrigger.Value = false;
handles.StopTrigger.Value = false;

if hObject.Value == 0
    handles.TrialTrigger.Enable = 'on';
    handles.StimTrigger.Enable = 'on';
    handles.StopTrigger.Enable = 'on';
    hObject.String = 'Released';
elseif hObject.Value == 1
    handles.TrialTrigger.Enable = 'off';
    handles.StimTrigger.Enable = 'off';
    handles.StopTrigger.Enable = 'off';
    hObject.String = 'Locked';
end


% --- Executes on button press in saveTIF.
function saveTIF_Callback(hObject, eventdata, handles)
% hObject    handle to saveTIF (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of saveTIF


% --- Executes on button press in CalibrationMode.
function CalibrationMode_Callback(hObject, eventdata, handles)
% hObject    handle to CalibrationMode (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of CalibrationMode

if hObject.Value

    %make sure preview is on
    handles.StartPreview.Value = true;
    StartPreview_Callback(handles.StartPreview, [], handles);

    % get image and center
    frame = getsnapshot(handles.vidObj);
    frame = frame(:,:,1);
    midFrame = round(size(frame)/2);

    % plot lines to preview window
    if size(handles.ImagePlot.Children,1) ~= 3
        delete(findall(handles.ImagePlot,'Type','line'))
        hold(handles.ImagePlot, 'on');
        plot(handles.ImagePlot, [1, size(frame,2)], [midFrame(1) midFrame(1)],'r', 'linewidth', 2);
        plot(handles.ImagePlot, [midFrame(2) midFrame(2)], [1, size(frame,1)],'r', 'linewidth', 2);
        hold(handles.ImagePlot, 'off');
    end

    % open calibration window
    try
        handles.Calibration.Children;
    catch
        handles.Calibration = figure('name','Calibration window','CloseRequestFcn',@(src,evt)closeCalibration(handles));
        subplot(2,1,1); subplot(2,1,2); handles.Calibration.MenuBar = 'none';

        handles.updateCalibration = timer('Period',0.1,... %period
            'ExecutionMode','fixedRate',... %{singleShot,fixedRate,fixedSpacing,fixedDelay}
            'BusyMode','drop',... %{drop, error, queue}
            'TasksToExecute',inf,...
            'StartDelay',0,...
            'TimerFcn',@(src,evt)plotCalibration(handles));
        start(handles.updateCalibration);
        guidata(handles.WidefieldImager, handles);
    end
else
    try
        delete(findall(handles.ImagePlot,'Type','line'))
        stop(handles.updateCalibration);
        close(handles.Calibration);
    end
end


function plotCalibration(handles)
% this is to update the contents of the calibration figure

% get image and center
frame = getsnapshot(handles.vidObj);
frame = frame(:,:,1);
midFrame = round(size(frame)/2);

% plot each line
ax = handles.Calibration.Children(2);
plot(ax, frame(midFrame(1), :))
ax.TickLength = [0 0]; ax.XTickLabel = []; ax.YTickLabel = [];
xlim(ax,[1 size(frame,2)]); ylim(ax,[0 intmax(class(frame))]);
title(ax,'Horizontal axis', 'FontSize', 15);

ax = handles.Calibration.Children(1);
plot(ax, frame(:, midFrame(2)))
ax.TickLength = [0 0]; ax.XTickLabel = []; ax.YTickLabel = [];
xlim(ax,[1 size(frame,1)]); ylim(ax,[0 intmax(class(frame))]);
title(ax,'Vertical axis', 'FontSize', 15);

function closeCalibration(handles)
% this is when the calibration figure gets closed

handles.CalibrationMode.Value = false;
CalibrationMode_Callback(handles.CalibrationMode, [], handles); drawnow;
delete(gcf);


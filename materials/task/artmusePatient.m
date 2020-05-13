function artmusePatient (subjectNumber, subjectName)
%
% function artmusePatient(subjectNumber, subjectName, startRun, endRun, fMRI, eyeTrack)
%
% artmuse - adapted for patient studies
% 2 images per trial; same / different judgment
% control condition: identical art or identical room used as matches
% experimental condition: same as artmuse01/artmuse02 stimuli, with similar-style art and same-layout rooms
% 10 trials of each state in blocked form x 8 blocks; control and experimental trials intermixed
%
% subjectNumber: self-explanatory
% subjectName: initials are handy
%
% Mariam Aly
% October 2016
%
% code was updated to automate the process of finding the keyboard you are
% using
%
% instructions were changed to 'press the 1 key. If it was absent, press
% the 2 key' from 'press the left key. If it was absent, press the right
% key'
%
% be sure to have this code in the same directory as the 'stimuli'
% folder
%
% if you receive an error that there are too many files in the stimuli
% directory, open a terminal window at the stimuli folder and paste 
% 'find . -name '*DS_Store' -type f -delete'
%
% this code will output a .mat and a .txt file
%
% behavioral results will also be printed into the command window
%
% nicholas ruiz
% september 2019
% =========================================================================

%% initial setup

    Screen('Preference', 'SkipSyncTests', 2);
    Screen('Preference', 'SuppressAllWarnings', 1);
    Screen('Preference', 'Verbosity', 0);
    Screen('Preference', 'VisualDebugLevel', 1);

    seed = sum(100*clock);
    rand('twister',seed);
    ListenChar(2);
    HideCursor;
    GetSecs;
    
%% some parameters

    % response keys
        PRESENT = KbName('1!'); 
        ABSENT = KbName('2@');

    % timing
        cueDuration = 0.5; % art / room text cue  
        stimDuration = 2.0; % for each 3D-rendered room
        stimOnsetTime = 0.5; % base image onset from beginning of trial
        ISI = 0.5; % between images and between 2nd image & probe
        % respWindow = 10.0; % will time out if no response given after this many seconds
            % commenting it out right now; I have it self-paced
        ITI = 2.0; % 2s break before next trial
        
    % trial numbers
        numExptTrials = 40; % total experimental trials
        numControlTrials = 40; % total control trials
        totalNumTrials = numExptTrials + numControlTrials;
        stimNum = 1:totalNumTrials; % should have this number unique base image trials in stimuli directory
        
        propValid = .8; % proportion of valid trials
        numValidTrialsEachStateExpt = round(numExptTrials/2 * propValid); % numExptTrials/2 (because 2 attentional states), * valid proportion
        numInvalidTrialsEachStateExpt = round(numExptTrials/2 * (1-propValid)); % same for invalid trials
        
        numValidTrialsEachStateControl = round(numControlTrials/2 * propValid); % numExptTrials/2 (because 2 attentional states), * valid proportion
        numInvalidTrialsEachStateControl = round(numControlTrials/2 * (1-propValid)); % same for invalid trials
           
     % block length in trials
        blockLength = 10; 
        numBlocks = totalNumTrials / blockLength;
        
        blockToStartWith = Shuffle([1,2]); % whether to start with art or room
        blockOrder = repmat([repmat(blockToStartWith(1), blockLength, 1); repmat(blockToStartWith(2), blockLength, 1)], numBlocks/2, 1);

        
%% keyboard
 
    KbName('UnifyKeyNames'); % platform-independent responses

    [index devName] = GetKeyboardIndices;

    DEVICENAME = devName(length(devName)); % calls in the keybard you are using
    
    for device = 1:length(index)
        if strcmp(devName(device),DEVICENAME)
            DEVICE = index(device);
        end
    end

    FlushEvents('keyDown');
    [keyIsDown, secs, keyCode] = KbCheck(DEVICE);
    
    
 %% set up screens

    screenNum = 0;

    % colors
        backColor = 255; 
        textColor = 0; 

    % main window setup
        [screenX screenY] = Screen('WindowSize',screenNum);
        % screenX = 1024; screenY = 768; % for debugging
        mainWindow = Screen(screenNum,'OpenWindow',backColor,[0 0 screenX screenY]);
        centerX = screenX/2; centerY = screenY/2;
        flipTime = Screen('GetFlipInterval', mainWindow);

    % fonts
        Screen('TextFont', mainWindow, 'Optima');
        Screen('TextSize', mainWindow, 32);

    % image setup
        imageSizeX= 600;
        imageSizeY = 450; 
        imageRect = [0,0,imageSizeX,imageSizeY];
        centerRect = [centerX-imageSizeX/2,centerY-imageSizeY/2,centerX+imageSizeX/2,centerY+imageSizeY/2];

    % color, size, and position of fixation dot
        fixationColor = 0; 
        respColor = 255; % remove fixation dot when response made (make it white like background)
        fixationSize = 4;
        fixDotRect = [centerX-fixationSize,centerY-fixationSize,centerX+fixationSize,centerY+fixationSize];
        
 
  %% set up conditions and randomize, separately for art and room blocks
 
        % conditions: control trials (0) or experimental trials(1)
            exptCond.art = [repmat(0,numControlTrials/2,1); repmat(1,numExptTrials/2,1)];
            exptCond.room = [repmat(0,numControlTrials/2,1); repmat(1,numExptTrials/2,1)];
 
        % cue type (art or room)
            cueType.art = [repmat(1, numControlTrials/2, 1); repmat(1, numExptTrials/2, 1)];
            cueType.room = [repmat(2, numControlTrials/2, 1); repmat(2, numExptTrials/2, 1)];
            
        % probe type (art or room)
            probeType.art = [repmat(1,numValidTrialsEachStateControl, 1); repmat(2,numInvalidTrialsEachStateControl, 1);repmat(1,numValidTrialsEachStateExpt, 1); repmat(2,numInvalidTrialsEachStateExpt, 1)];
            probeType.room = [repmat(2,numValidTrialsEachStateControl, 1); repmat(1,numInvalidTrialsEachStateControl, 1);repmat(2,numValidTrialsEachStateExpt, 1); repmat(1,numInvalidTrialsEachStateExpt, 1)];
                 
        % cue validity (0 = invalid, 1 = valid)
            cueValidity.art(cueType.art == probeType.art) = 1;
            cueValidity.art(cueType.art ~= probeType.art) = 0;
            cueValidity.art = cueValidity.art';
        
            cueValidity.room(cueType.room == probeType.room) = 1;
            cueValidity.room(cueType.room ~= probeType.room) = 0;
            cueValidity.room = cueValidity.room';
                   
        % show art or room match? probed match shown 50% of the time
        
            % on valid trials, cued match is shown 50% of the time; on remaining 50% of valid trials, other match is shown half the time, neither match shown half the time
            % on invalid trials, other (probed) match is shown 50% of the time; on remaining 50% of invalid trials, cued match is shown half the time, neither match shown half the time
            
                cuedMatchShown.art = [repmat(0,numValidTrialsEachStateControl/2,1); repmat(1,numValidTrialsEachStateControl/2,1); repmat(0,numInvalidTrialsEachStateControl/4,1); repmat(1,numInvalidTrialsEachStateControl/4,1);repmat(0,numInvalidTrialsEachStateControl/2,1); repmat(0,numValidTrialsEachStateExpt/2,1); repmat(1,numValidTrialsEachStateExpt/2,1); repmat(0,numInvalidTrialsEachStateExpt/4,1); repmat(1,numInvalidTrialsEachStateExpt/4,1);repmat(0,numInvalidTrialsEachStateExpt/2,1)];
                cuedMatchShown.room = [repmat(0,numValidTrialsEachStateControl/2,1); repmat(1,numValidTrialsEachStateControl/2,1); repmat(0,numInvalidTrialsEachStateControl/4,1); repmat(1,numInvalidTrialsEachStateControl/4,1);repmat(0,numInvalidTrialsEachStateControl/2,1); repmat(0,numValidTrialsEachStateExpt/2,1); repmat(1,numValidTrialsEachStateExpt/2,1); repmat(0,numInvalidTrialsEachStateExpt/4,1); repmat(1,numInvalidTrialsEachStateExpt/4,1);repmat(0,numInvalidTrialsEachStateExpt/2,1)]; 

                otherMatchShown.art = [repmat(0,numValidTrialsEachStateControl/4,1); repmat(1,numValidTrialsEachStateControl/4,1); repmat(0,numValidTrialsEachStateControl/2,1); repmat(0,numInvalidTrialsEachStateControl/2,1); repmat(1,numInvalidTrialsEachStateControl/2,1); repmat(0,numValidTrialsEachStateExpt/4,1); repmat(1,numValidTrialsEachStateExpt/4,1); repmat(0,numValidTrialsEachStateExpt/2,1); repmat(0,numInvalidTrialsEachStateExpt/2,1); repmat(1,numInvalidTrialsEachStateExpt/2,1)];
                otherMatchShown.room = [repmat(0,numValidTrialsEachStateControl/4,1); repmat(1,numValidTrialsEachStateControl/4,1); repmat(0,numValidTrialsEachStateControl/2,1); repmat(0,numInvalidTrialsEachStateControl/2,1); repmat(1,numInvalidTrialsEachStateControl/2,1); repmat(0,numValidTrialsEachStateExpt/4,1); repmat(1,numValidTrialsEachStateExpt/4,1); repmat(0,numValidTrialsEachStateExpt/2,1); repmat(0,numInvalidTrialsEachStateExpt/2,1); repmat(1,numInvalidTrialsEachStateExpt/2,1)];  

        % correct response (0 for trials when probed match was not shown; 1 for trials in which probed match was shown)
            correctResponse.art(cueValidity.art == 1) = cuedMatchShown.art(cueValidity.art == 1); % on valid trials, correct response is based on whether the cued match was shown
            correctResponse.art(cueValidity.art == 0) = otherMatchShown.art(cueValidity.art == 0); % on invalid trials, correct response is based on whether the other match was shown
            correctResponse.art = correctResponse.art';
            
            correctResponse.room(cueValidity.room == 1) = cuedMatchShown.room(cueValidity.room == 1); % on valid trials, correct response is based on whether the cued match was shown
            correctResponse.room(cueValidity.room == 0) = otherMatchShown.room(cueValidity.room == 0); % on invalid trials, correct response is based on whether the other match was shown
            correctResponse.room = correctResponse.room';
                       
        % randomly assign stimuli to conditions, and randomize trial order
            stimOrder = Shuffle(stimNum)'; % shuffle stimuli
            shuffledStimOrder.art = stimOrder(1:length(stimOrder)/2);
            shuffledStimOrder.room = stimOrder((length(stimOrder)/2 + 1):end);
            
            shuffledTrialOrder.art = Shuffle(1:totalNumTrials/2)'; % this is to shuffle the trial/condition types, which will all be shuffled in the same order to preserve the counterbalancing I did above
            exptCond.art = exptCond.art(shuffledTrialOrder.art);
            cueType.art = cueType.art(shuffledTrialOrder.art);
            probeType.art = probeType.art(shuffledTrialOrder.art);
            cueValidity.art = cueValidity.art(shuffledTrialOrder.art);
            cuedMatchShown.art = cuedMatchShown.art(shuffledTrialOrder.art);
            otherMatchShown.art = otherMatchShown.art(shuffledTrialOrder.art);
            correctResponse.art = correctResponse.art(shuffledTrialOrder.art);
            
            shuffledTrialOrder.room = Shuffle(1:totalNumTrials/2)'; % this is to shuffle the trial/condition types, which will all be shuffled in the same order to preserve the counterbalancing I did above
            exptCond.room = exptCond.room(shuffledTrialOrder.room);
            cueType.room = cueType.room(shuffledTrialOrder.room);
            probeType.room = probeType.room(shuffledTrialOrder.room);
            cueValidity.room = cueValidity.room(shuffledTrialOrder.room);
            cuedMatchShown.room = cuedMatchShown.room(shuffledTrialOrder.room);
            otherMatchShown.room = otherMatchShown.room(shuffledTrialOrder.room);
            correctResponse.room = correctResponse.room(shuffledTrialOrder.room);
            
            
 %% save setup variables in 'stim' structure 
 
    stim.shuffledStimOrder = shuffledStimOrder;
    stim.shuffledTrialOrder = shuffledTrialOrder;
    stim.exptCond = exptCond;
    stim.cueType = cueType;
    stim.probeType = probeType;
    stim.cueValidity = cueValidity;
    stim.cuedMatchShown = cuedMatchShown;
    stim.otherMatchShown = otherMatchShown;
    stim.correctResponse = correctResponse;
          
    filename = strcat('artmusePatient_', num2str(subjectNumber), '_', subjectName); 
           
    save(filename, 'stim');            
            
%% reset counters for keeping track of H/M/FA/CR rates online

    % experimental trials
        expt_numValid_ArtProbe_Present = 0; expt_numValid_ArtProbe_Absent = 0;   
        expt_numValid_ArtProbe_Hits = 0; expt_numValid_ArtProbe_Misses = 0; expt_numValid_ArtProbe_FA = 0; expt_numValid_ArtProbe_CR = 0;
            
        expt_numValid_RoomProbe_Present = 0; expt_numValid_RoomProbe_Absent = 0;  
        expt_numValid_RoomProbe_Hits = 0; expt_numValid_RoomProbe_Misses = 0; expt_numValid_RoomProbe_FA = 0; expt_numValid_RoomProbe_CR = 0;    
               
        expt_numInvalid_ArtProbe_Present = 0; expt_numInvalid_ArtProbe_Absent = 0;   
        expt_numInvalid_ArtProbe_Hits = 0; expt_numInvalid_ArtProbe_Misses = 0; expt_numInvalid_ArtProbe_FA = 0; expt_numInvalid_ArtProbe_CR = 0;  
                   
        expt_numInvalid_RoomProbe_Present = 0; expt_numInvalid_RoomProbe_Absent = 0;  
        expt_numInvalid_RoomProbe_Hits = 0; expt_numInvalid_RoomProbe_Misses = 0; expt_numInvalid_RoomProbe_FA = 0; expt_numInvalid_RoomProbe_CR = 0;
        
             
     % control trials   
         cntrl_numValid_ArtProbe_Present = 0; cntrl_numValid_ArtProbe_Absent = 0;     
         cntrl_numValid_ArtProbe_Hits = 0; cntrl_numValid_ArtProbe_Misses = 0; cntrl_numValid_ArtProbe_FA = 0; cntrl_numValid_ArtProbe_CR = 0;
                
         cntrl_numValid_RoomProbe_Present = 0; cntrl_numValid_RoomProbe_Absent = 0;     
         cntrl_numValid_RoomProbe_Hits = 0; cntrl_numValid_RoomProbe_Misses = 0; cntrl_numValid_RoomProbe_FA = 0; cntrl_numValid_RoomProbe_CR = 0;        

         cntrl_numInvalid_ArtProbe_Present = 0; cntrl_numInvalid_ArtProbe_Absent = 0;
         cntrl_numInvalid_ArtProbe_Hits = 0; cntrl_numInvalid_ArtProbe_Misses = 0; cntrl_numInvalid_ArtProbe_FA = 0; cntrl_numInvalid_ArtProbe_CR = 0;
                  
         cntrl_numInvalid_RoomProbe_Present = 0; cntrl_numInvalid_RoomProbe_Absent = 0;    
         cntrl_numInvalid_RoomProbe_Hits = 0; cntrl_numInvalid_RoomProbe_Misses = 0; cntrl_numInvalid_RoomProbe_FA = 0; cntrl_numInvalid_RoomProbe_CR = 0;
        
                  
%% load images

    cd stimuli
    
    dirList = dir;
    dirList = dirList(3:end);
    numUniqueTrials = length(dirList); 
    
    if numUniqueTrials ~= length(stimNum)
        fprintf('You do not have the correct number of images in the directory\n');
    else
        fprintf('Number of images in directory matches number of trials\n');
    end
    
    imageTex = zeros(numUniqueTrials,6); % replace 6 with however many images are in each folder

    for uniqueTrial=1:numUniqueTrials
        
        instructString = ['Loading unique trial ' num2str(uniqueTrial) ' of ' num2str(numUniqueTrials)];
        boundRect = Screen('TextBounds',mainWindow,instructString);
        Screen('DrawText', mainWindow, instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor);
        Screen('Flip',mainWindow);

        cd(dirList(uniqueTrial).name)
        tmpList = dir('*.jpg');

        if (length(tmpList)~=6) % replace 6 with however many images are in each folder
            instructString = ['Loading unique trial ' num2str(uniqueTrial) ' of ' num2str(numUniqueTrials)];
            boundRect = Screen('TextBounds',mainWindow,instructString);
            Screen('DrawText', mainWindow, instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor);

            instructString = ['Not enough images in ' dirList(uniqueTrial).name];
            boundRect = Screen('TextBounds',mainWindow,instructString);
            Screen('DrawText', mainWindow, instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+40, textColor);
            Screen('Flip',mainWindow);
        end

        for imageNumber = 1:6; % replace 6 with however many images are in each folder
            tmpMat = imread(tmpList(imageNumber).name);
            imageTex(uniqueTrial,imageNumber) = Screen('MakeTexture', mainWindow, tmpMat);
        end

            % in imageTex: 
                 % 1st column is base image 
                 % 2nd is art match
                 % 3rd is room match
                 % 4th is identical art in new room
                 % 5th is new art with identical room
                 % 6th is new art with new room

        cd ../ % go to stimuli directory

    end

    cd ../ % go to main experiment directory
    
%% open and set up files for data collection / on-line monitoring

    % open and set up files for data collection
        dataFile = fopen(['artmusePatient_' num2str(subjectNumber) '_' subjectName '.txt'],'a'); 
        fprintf(dataFile,'************************************************\n'); 
        fprintf(dataFile, '* artmuse patient study\n'); 
        fprintf(dataFile, ['* date/time: ' datestr(now,0) '\n']);  
        fprintf(dataFile, ['* seed: ' num2str(seed) '\n']); 
        fprintf(dataFile, ['* subject #: ' num2str(subjectNumber) '\n']);
        fprintf(dataFile, ['* subject name: ' subjectName '\n']);
        fprintf(dataFile,'************************************************\n\n');

    % print to command window to monitor real-time performance (in dual-screen mode)
        fprintf('************************************************\n'); 
        fprintf('* artmuse patient study\n'); 
        fprintf(['* date/time: ' datestr(now,0) '\n']);  
        fprintf(['* seed: ' num2str(seed) '\n']); 
        fprintf(['* subject #: ' num2str(subjectNumber) '\n']);
        fprintf(['* subject name: ' subjectName '\n']);
        fprintf('************************************************\n\n');
        
     % headings for the data files 
        fprintf(dataFile,'trial\tstimOnsetTime\texptCond\tstimNum\tcue\tprobe\tvalid\tresp\tcorResp\tAcc\tRT\te_VArtH\t\te_VArtFA\te_VRoomH\te_VRoomFA\te_IVArtH\te_IVArtFA\te_IVRoomH\te_IVRoomFA\tc_VArtH\tc_VArtFA\tc_VRoomH\tc_VRoomFA\tc_IVArtH\tc_IVArtFA\tc_IVRoomH\tc_IVRoomFA\n');
        fprintf('trial\tstimOnsetTime\texptCond\tstimNum\tcue\tprobe\tvalid\tresp\tcorResp\tAcc\tRT\te_VArtH\t\te_VArtFA\te_VRoomH\te_VRoomFA\te_IVArtH\te_IVArtFA\te_IVRoomH\te_IVRoomFA\tc_VArtH\tc_VArtFA\tc_VRoomH\tc_VRoomFA\tc_IVArtH\tc_IVArtFA\tc_IVRoomH\tc_IVRoomFA\n');
    
 %% display instructions

    instructString = 'Welcome! Please wait for instructions.';
    boundRect = Screen('TextBounds', mainWindow, instructString); 
    Screen('DrawText', mainWindow, instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor); 
    Screen('Flip', mainWindow);
  
    while(1) 
        FlushEvents('keyDown');
        temp = GetChar;
        if (temp == ' ') 
            break;
        end
    end

    FlushEvents;
    WaitSecs(.2);

    % instructions

        instructString = 'Imagine you are going to pay a few visits to a unique house with a lot of art on the walls.';
        boundRect = Screen('TextBounds', mainWindow, instructString); 
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-310, textColor);

        instructString = 'The owners like to have at least two pieces of art by the same artist.';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-260, textColor); 

        instructString = 'There are also a lot of rooms, and the owners change the paint colors and the furniture pretty often.';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-210, textColor);

        instructString = 'You want to see if you can identify pieces of art that were painted by the same arist.';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-150, textColor);
        
        instructString = '(whether or not it''s the same exact painting)';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-100, textColor);

        instructString = 'And also if you can identify the same room.';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-40, textColor);
        
        instructString = '(whether or not it''s been redecorated, and seen from a different perspective)';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/+10, textColor);

        instructString = 'On every trial, a cue will tell you whether to pay attention to the art or to the room.';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+70, textColor);

        instructString = 'You will then see a room with a piece of art in it, followed by another room with art.';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+120, textColor);

        instructString = 'You will then be asked whether the paintings could have been painted by the same artist (ART?)';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+170, textColor);
        
        instructString = 'OR';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+220, textColor);
        
        instructString = 'whether those rooms had the same furniture layout and wall configuration (ROOM?)';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+270, textColor);
         
        instructString = 'If the match you are asked about was present, press the 1 key. If it was absent, press the 2 key.';
        boundRect = Screen('TextBounds', mainWindow, instructString);
        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+320, textColor);

        Screen('Flip',mainWindow);

        while(1) 
            FlushEvents('keyDown');
            temp = GetChar;
            if (temp == ' ') 
                break;
            end
        end

    WaitSecs(.2);
    
    
%% start experiment

    accuracy = 0;

    Screen('FillRect', mainWindow, backColor);
    Screen('Flip',mainWindow);

    Priority(MaxPriority(mainWindow)); 

    block = 1;
    artTrialNum = 1;
    roomTrialNum = 1;
    

     %% trial loop
    
        for trial = 1:totalNumTrials
            
            if trial == 1
                               
                  % present instructions for this block
                       if blockOrder(trial) == 1    
                            instructString = 'You will be paying attention to the ART for the next few trials.';
                            boundRect = Screen('TextBounds', mainWindow, instructString);
                            Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-40, textColor);
                            
                            instructString = 'You want to see if the 2 paintings could have been painted by the same person.';
                            boundRect = Screen('TextBounds', mainWindow, instructString);
                            Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor);

                            instructString = 'Are you ready?';  
                                boundRect = Screen('TextBounds', mainWindow, instructString); 
                                Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+40, textColor);
                                Screen('Flip',mainWindow);

                                while(1) 
                                    FlushEvents('keyDown');
                                    temp = GetChar;
                                    if (temp == ' ') 
                                        break;
                                    end
                                end
                                
                                startExptTime = GetSecs;

                        elseif blockOrder(trial) == 2
                            instructString = 'You will be paying attention to the ROOMS for the next few trials.';
                            boundRect = Screen('TextBounds', mainWindow, instructString);
                            Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-40, textColor);
                            
                            instructString = 'You want to see if the 2 rooms have the same layout.';
                            boundRect = Screen('TextBounds', mainWindow, instructString);
                            Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor);

                            instructString = 'Are you ready?';  
                                boundRect = Screen('TextBounds', mainWindow, instructString); 
                                Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+40, textColor);
                                Screen('Flip',mainWindow);
                                
                                while(1) 
                                    FlushEvents('keyDown');
                                    temp = GetChar;
                                    if (temp == ' ') 
                                        break;
                                    end
                                end
                                
                                startExptTime = GetSecs;
         

                       end
    
            elseif trial == totalNumTrials / numBlocks * block + 1; % pause at the end of each block; give feedback and new insructions

                % give feedback 
                    % accuracyPercentage = (accuracy/(totalNumTrials/numBlocks*block))*100;
                        % this is for calculating cumulative accuracy across all experiment blocks
                        % if you want to do this, don't reset accuracy to 0 below
                    accuracyPercentage = (accuracy/(totalNumTrials/numBlocks))*100;

                    instructString = ['Your accuracy for this set of trials was ' num2str(accuracyPercentage) '%'];
                    boundRect = Screen('TextBounds', mainWindow, instructString); 
                    Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-60, textColor);

                    if accuracyPercentage <=60
                        instructString = 'This task is challenging, but keep trying!';
                    elseif 60 < accuracyPercentage && accuracyPercentage <= 75
                        instructString = 'You are doing ok! Keep it up!'; 
                    elseif 75 < accuracyPercentage && accuracyPercentage <=90
                        instructString = 'You are doing very well! Keep it up!';
                    elseif accuracyPercentage > 90
                        instructString = 'Wow! You are doing amazingly well! Keep it up!';
                    end

                    boundRect = Screen('TextBounds', mainWindow, instructString); 
                    Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-10, textColor);

                % get ready to start again
                    instructString = 'The task will start again soon. Please wait for more instructions.';  
                    boundRect = Screen('TextBounds', mainWindow, instructString); 
                    Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+40, textColor);
                    Screen('Flip',mainWindow);

                    while(1) 
                        FlushEvents('keyDown');
                        temp = GetChar;
                        if (temp == ' ') 
                            break;
                        end
                    end
                    
               % present instructions for this block
            
                   if blockOrder(trial) == 1    
                       instructString = 'You will be paying attention to the ART for the next few trials.';
                       boundRect = Screen('TextBounds', mainWindow, instructString);
                       Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-40, textColor);
                       
                       instructString = 'You want to see if the 2 paintings could have been painted by the same person.';
                       boundRect = Screen('TextBounds', mainWindow, instructString);
                       Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor);
                       
                       instructString = 'Are you ready?';
                       boundRect = Screen('TextBounds', mainWindow, instructString);
                       Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+40, textColor);
                       Screen('Flip',mainWindow);
                       
                       while(1)
                           FlushEvents('keyDown');
                           temp = GetChar;
                           if (temp == ' ')
                               break;
                           end
                       end

                    elseif blockOrder(trial) == 2
                        instructString = 'You will be paying attention to the ROOMS for the next few trials.';
                        boundRect = Screen('TextBounds', mainWindow, instructString);
                        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-40, textColor);
                        
                        instructString = 'You want to see if the 2 rooms have the same layout.';
                        boundRect = Screen('TextBounds', mainWindow, instructString);
                        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor);
                        
                        instructString = 'Are you ready?';
                        boundRect = Screen('TextBounds', mainWindow, instructString);
                        Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5+40, textColor);
                        Screen('Flip',mainWindow);
                        
                        while(1)
                            FlushEvents('keyDown');
                            temp = GetChar;
                            if (temp == ' ')
                                break;
                            end
                        end
                   end
            

                    accuracy = 0; % reset accuracy to 0 for next set of trials
                    block = block + 1;

                    Screen('FillRect', mainWindow, backColor);
                    Screen('Flip',mainWindow);
                    Priority(MaxPriority(mainWindow));

                    % runTime = GetSecs;

            end
            
                  
       % start
            
           % reset temporary variables
                thisResponse = NaN; thisAcc = NaN; thisRT = NaN;

           % get conditions for this trial
                if blockOrder(trial) == 1
                    
                    tmpStim = shuffledStimOrder.art(artTrialNum);
                    tmpExptCond = exptCond.art(artTrialNum);
                    tmpCueType = cueType.art(artTrialNum);
                    tmpProbeType = probeType.art(artTrialNum);
                    tmpCueValidity = cueValidity.art(artTrialNum);
                    tmpCuedMatchShown = cuedMatchShown.art(artTrialNum);
                    tmpOtherMatchShown = otherMatchShown.art(artTrialNum);
                    tmpCorrectResponse = correctResponse.art(artTrialNum);
                    
                    artTrialNum = artTrialNum + 1;
                    
                elseif blockOrder(trial) == 2
                               
                    tmpStim = shuffledStimOrder.room(roomTrialNum);
                    tmpExptCond = exptCond.room(roomTrialNum);
                    tmpCueType = cueType.room(roomTrialNum);
                    tmpProbeType = probeType.room(roomTrialNum);
                    tmpCueValidity = cueValidity.room(roomTrialNum);
                    tmpCuedMatchShown = cuedMatchShown.room(roomTrialNum);
                    tmpOtherMatchShown = otherMatchShown.room(roomTrialNum);
                    tmpCorrectResponse = correctResponse.room(roomTrialNum);
                    
                    roomTrialNum = roomTrialNum + 1;
                    
                end
 
         % get stimuli for this trial
            tmpTex(1) = imageTex(tmpStim,1); % texture index for base image
            tmpTex(2) = imageTex(tmpStim,2); % art match
            tmpTex(3) = imageTex(tmpStim,3); % room match
            tmpTex(4) = imageTex(tmpStim,4); % identical art in new room
            tmpTex(5) = imageTex(tmpStim,5); % new art in identical room
            tmpTex(6) = imageTex(tmpStim,6); % new art in new room
                 
        % start the image presentations
            runTime = GetSecs;
            trialStart = runTime + ITI; 
            
            % show fixation 500 ms before trial
                while(trialStart - GetSecs > .5); end 
                Screen('FillRect',mainWindow,backColor); 
                Screen('FillOval',mainWindow,fixationColor,fixDotRect);
                Screen('Flip',mainWindow);
                
            % show attention cue
                if tmpCueType == 1;
                    instructString = 'ART';
                    boundRect = Screen('TextBounds', mainWindow, instructString); 
                    Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-50, textColor);
                    Screen('FillOval',mainWindow, fixationColor,fixDotRect);
                    trialStartTime = Screen('Flip',mainWindow,trialStart-flipTime); % save time that screen was flipped in trialStartTime
                elseif tmpCueType ==2;
                    instructString = 'ROOM';
                    boundRect = Screen('TextBounds', mainWindow, instructString); 
                    Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-50, textColor);
                    trialStartTime = Screen('Flip',mainWindow,trialStart-flipTime); % save time that screen was flipped in trialStartTime
                end
                
            % cue offset
                Screen(mainWindow,'FillRect',backColor);
                % Screen('FillOval',mainWindow, fixationColor,fixDotRect);
                Screen('Flip',mainWindow,trialStartTime+cueDuration); 
            
            % show base image 
                Screen('DrawTexture',mainWindow,tmpTex(1),imageRect,centerRect);
                % Screen('FillOval',mainWindow, fixationColor,fixDotRect);
                Screen('Flip',mainWindow,trialStartTime + stimOnsetTime);
      
            % ISI
                Screen(mainWindow,'FillRect',backColor);
                % Screen('FillOval',mainWindow, fixationColor,fixDotRect);
                Screen('Flip',mainWindow,trialStartTime + stimOnsetTime + stimDuration);
                
            % show the second image
                if tmpExptCond == 0 % control condition
                    if tmpCueType == 1 && tmpCuedMatchShown == 1 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(4); % show identical art, new room
                    elseif tmpCueType == 1 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 1
                        imageToShow = tmpTex(5); % show new art, identical room
                    elseif tmpCueType == 1 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(6); % show new art, new room
                    elseif tmpCueType == 2 && tmpCuedMatchShown == 1 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(5); % show identical room, new art
                    elseif tmpCueType == 2 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 1
                        imageToShow = tmpTex(4); % show new room, identical art
                    elseif tmpCueType == 2 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(6); % show new room, new art
                    end
                elseif tmpExptCond == 1 % experimental condition
                    if tmpCueType == 1 && tmpCuedMatchShown == 1 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(2); % show art match
                    elseif tmpCueType == 1 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 1
                        imageToShow = tmpTex(3); % show room match
                    elseif tmpCueType == 1 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(6); % show new art, new room
                    elseif tmpCueType == 2 && tmpCuedMatchShown == 1 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(3); % show room match
                    elseif tmpCueType == 2 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 1
                        imageToShow = tmpTex(2); % show art match
                    elseif tmpCueType == 2 && tmpCuedMatchShown == 0 && tmpOtherMatchShown == 0
                        imageToShow = tmpTex(6); % show new room, new art
                    end
                end

                Screen('DrawTexture',mainWindow,imageToShow,imageRect,centerRect);
                % Screen('FillOval',mainWindow, fixationColor,fixDotRect);
                Screen('Flip',mainWindow,trialStartTime + stimOnsetTime + stimDuration + ISI);
                                 
           % present probe and collect response
                if tmpProbeType == 1;
                    instructString = 'ART ?';
                elseif tmpProbeType == 2;
                    instructString = 'ROOM ?';
                end
                
                boundRect = Screen('TextBounds', mainWindow, instructString);
                Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-50, textColor);
                Screen('FillOval',mainWindow, fixationColor,fixDotRect);
                probeStart = Screen('Flip',mainWindow,trialStartTime + stimOnsetTime + stimDuration + ISI + stimDuration); % save time that screen was flipped in probeStart
                                      
            % as soon as probe comes up, listen for response
                FlushEvents('keyDown');
                % while (GetSecs < probeStart+respWindow) % self-paced for now
                    while(1)
                        if isnan(thisRT) 
                            [keyIsDown, secs, keyCode] = KbCheck(DEVICE); 
                            if (keyIsDown) 
                                if (keyCode(PRESENT) || keyCode(ABSENT)) 
                                    thisRT = secs - probeStart; 
                                    if keyCode(PRESENT)
                                        thisResponse = 1;
                                    elseif keyCode(ABSENT)
                                        thisResponse = 0; 
                                    else
                                        thisResponse = NaN;
                                    end

                                    if ( thisResponse == 1 && tmpCorrectResponse == 1) || ( thisResponse == 0 && tmpCorrectResponse == 0)
                                        thisAcc = 1;
                                        accuracy = accuracy + 1; 
                                    elseif ( thisResponse == 0 && tmpCorrectResponse == 1) || ( thisResponse == 1 && tmpCorrectResponse == 0)
                                        thisAcc = 0;
                                    else
                                        thisAcc = NaN;
                                    end

                                    Screen(mainWindow,'FillOval',respColor,fixDotRect); % remove fixation dot when response registered
                                    Screen('Flip',mainWindow);
                                    Priority(0);
                                    
                                    break;

                                end
                            end
                        end
                    end

        %% after response (still during trial, loop not over yet): classify response type (Hit/Miss/CR/FA) and calculate cumulative H/M/CR/FAR 
        
        if tmpExptCond == 0 % control trials
            
            % valid trials
                if (tmpProbeType == 1 && tmpCueValidity == 1 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        cntrl_numValid_ArtProbe_Present = cntrl_numValid_ArtProbe_Present + 1;
                        cntrl_numValid_ArtProbe_Hits = cntrl_numValid_ArtProbe_Hits +1;
                    elseif thisResponse == 0
                        cntrl_numValid_ArtProbe_Present = cntrl_numValid_ArtProbe_Present + 1;
                        cntrl_numValid_ArtProbe_Misses = cntrl_numValid_ArtProbe_Misses + 1;
                    end        
                elseif (tmpProbeType == 1 && tmpCueValidity == 1 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        cntrl_numValid_ArtProbe_Absent = cntrl_numValid_ArtProbe_Absent + 1;
                        cntrl_numValid_ArtProbe_FA = cntrl_numValid_ArtProbe_FA +1;
                    elseif thisResponse == 0
                        cntrl_numValid_ArtProbe_Absent = cntrl_numValid_ArtProbe_Absent + 1;
                        cntrl_numValid_ArtProbe_CR = cntrl_numValid_ArtProbe_CR + 1;
                    end         
                elseif (tmpProbeType == 2 && tmpCueValidity == 1 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        cntrl_numValid_RoomProbe_Present = cntrl_numValid_RoomProbe_Present + 1;
                        cntrl_numValid_RoomProbe_Hits = cntrl_numValid_RoomProbe_Hits +1;
                    elseif thisResponse == 0
                        cntrl_numValid_RoomProbe_Present = cntrl_numValid_RoomProbe_Present + 1;
                        cntrl_numValid_RoomProbe_Misses = cntrl_numValid_RoomProbe_Misses + 1;
                    end            
                elseif (tmpProbeType == 2 && tmpCueValidity == 1 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        cntrl_numValid_RoomProbe_Absent = cntrl_numValid_RoomProbe_Absent + 1;
                        cntrl_numValid_RoomProbe_FA = cntrl_numValid_RoomProbe_FA + 1;
                    elseif thisResponse == 0
                        cntrl_numValid_RoomProbe_Absent = cntrl_numValid_RoomProbe_Absent + 1;
                        cntrl_numValid_RoomProbe_CR = cntrl_numValid_RoomProbe_CR +1;

                    end
                end
            
            % invalid trials
                if (tmpProbeType == 1 && tmpCueValidity == 0 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        cntrl_numInvalid_ArtProbe_Present = cntrl_numInvalid_ArtProbe_Present + 1;
                        cntrl_numInvalid_ArtProbe_Hits = cntrl_numInvalid_ArtProbe_Hits +1;
                    elseif thisResponse == 0
                        cntrl_numInvalid_ArtProbe_Present = cntrl_numInvalid_ArtProbe_Present + 1;
                        cntrl_numInvalid_ArtProbe_Misses = cntrl_numInvalid_ArtProbe_Misses +1;
                    end     
                elseif (tmpProbeType == 1 && tmpCueValidity == 0 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        cntrl_numInvalid_ArtProbe_Absent = cntrl_numInvalid_ArtProbe_Absent + 1;
                        cntrl_numInvalid_ArtProbe_FA = cntrl_numInvalid_ArtProbe_FA +1;
                    elseif thisResponse == 0
                        cntrl_numInvalid_ArtProbe_Absent = cntrl_numInvalid_ArtProbe_Absent + 1;
                        cntrl_numInvalid_ArtProbe_CR = cntrl_numInvalid_ArtProbe_CR +1;
                    end         
                elseif (tmpProbeType == 2 && tmpCueValidity == 0 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        cntrl_numInvalid_RoomProbe_Present = cntrl_numInvalid_RoomProbe_Present + 1;
                        cntrl_numInvalid_RoomProbe_Hits = cntrl_numInvalid_RoomProbe_Hits +1;
                    elseif thisResponse == 0
                        cntrl_numInvalid_RoomProbe_Present = cntrl_numInvalid_RoomProbe_Present + 1;
                        cntrl_numInvalid_RoomProbe_Misses = cntrl_numInvalid_RoomProbe_Misses +1;
                    end                
                elseif (tmpProbeType == 2 && tmpCueValidity == 0 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        cntrl_numInvalid_RoomProbe_Absent = cntrl_numInvalid_RoomProbe_Absent + 1;
                        cntrl_numInvalid_RoomProbe_FA = cntrl_numInvalid_RoomProbe_FA +1;
                    elseif thisResponse == 0
                        cntrl_numInvalid_RoomProbe_Absent = cntrl_numInvalid_RoomProbe_Absent + 1;
                        cntrl_numInvalid_RoomProbe_CR = cntrl_numInvalid_RoomProbe_CR +1;                  
                    end
                end
                     
            
        elseif tmpExptCond == 1 % experimental trials
            % valid trials
                if (tmpProbeType == 1 && tmpCueValidity == 1 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        expt_numValid_ArtProbe_Present = expt_numValid_ArtProbe_Present + 1;
                        expt_numValid_ArtProbe_Hits = expt_numValid_ArtProbe_Hits +1;
                    elseif thisResponse == 0
                        expt_numValid_ArtProbe_Present = expt_numValid_ArtProbe_Present + 1;
                        expt_numValid_ArtProbe_Misses = expt_numValid_ArtProbe_Misses + 1;
                    end           
                elseif (tmpProbeType == 1 && tmpCueValidity == 1 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        expt_numValid_ArtProbe_Absent = expt_numValid_ArtProbe_Absent + 1;
                        expt_numValid_ArtProbe_FA = expt_numValid_ArtProbe_FA +1;
                    elseif thisResponse == 0
                        expt_numValid_ArtProbe_Absent = expt_numValid_ArtProbe_Absent + 1;
                        expt_numValid_ArtProbe_CR = expt_numValid_ArtProbe_CR + 1;
                    end
                elseif (tmpProbeType == 2 && tmpCueValidity == 1 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        expt_numValid_RoomProbe_Present = expt_numValid_RoomProbe_Present + 1;
                        expt_numValid_RoomProbe_Hits = expt_numValid_RoomProbe_Hits +1;
                    elseif thisResponse == 0
                        expt_numValid_RoomProbe_Present = expt_numValid_RoomProbe_Present + 1;
                        expt_numValid_RoomProbe_Misses = expt_numValid_RoomProbe_Misses + 1;
                    end
                elseif (tmpProbeType == 2 && tmpCueValidity == 1 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        expt_numValid_RoomProbe_Absent = expt_numValid_RoomProbe_Absent + 1;
                        expt_numValid_RoomProbe_FA = expt_numValid_RoomProbe_FA + 1;
                    elseif thisResponse == 0
                        expt_numValid_RoomProbe_Absent = expt_numValid_RoomProbe_Absent + 1;
                        expt_numValid_RoomProbe_CR = expt_numValid_RoomProbe_CR +1;  
                    end
                end
                   
            % invalid trials
                if (tmpProbeType == 1 && tmpCueValidity == 0 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        expt_numInvalid_ArtProbe_Present = expt_numInvalid_ArtProbe_Present + 1;
                        expt_numInvalid_ArtProbe_Hits = expt_numInvalid_ArtProbe_Hits +1;
                    elseif thisResponse == 0
                        expt_numInvalid_ArtProbe_Present = expt_numInvalid_ArtProbe_Present + 1;
                        expt_numInvalid_ArtProbe_Misses = expt_numInvalid_ArtProbe_Misses +1;
                    end

                elseif (tmpProbeType == 1 && tmpCueValidity == 0 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        expt_numInvalid_ArtProbe_Absent = expt_numInvalid_ArtProbe_Absent + 1;
                        expt_numInvalid_ArtProbe_FA = expt_numInvalid_ArtProbe_FA +1;
                    elseif thisResponse == 0
                        expt_numInvalid_ArtProbe_Absent = expt_numInvalid_ArtProbe_Absent + 1;
                        expt_numInvalid_ArtProbe_CR = expt_numInvalid_ArtProbe_CR +1;
                    end

                elseif (tmpProbeType == 2 && tmpCueValidity == 0 && tmpCorrectResponse == 1)
                    if thisResponse == 1
                        expt_numInvalid_RoomProbe_Present = expt_numInvalid_RoomProbe_Present + 1;
                        expt_numInvalid_RoomProbe_Hits = expt_numInvalid_RoomProbe_Hits +1;
                    elseif thisResponse == 0
                        expt_numInvalid_RoomProbe_Present = expt_numInvalid_RoomProbe_Present + 1;
                        expt_numInvalid_RoomProbe_Misses = expt_numInvalid_RoomProbe_Misses +1;
                    end

                elseif (tmpProbeType == 2 && tmpCueValidity == 0 && tmpCorrectResponse == 0)
                    if thisResponse == 1
                        expt_numInvalid_RoomProbe_Absent = expt_numInvalid_RoomProbe_Absent + 1;
                        expt_numInvalid_RoomProbe_FA = expt_numInvalid_RoomProbe_FA +1;
                    elseif thisResponse == 0
                        expt_numInvalid_RoomProbe_Absent = expt_numInvalid_RoomProbe_Absent + 1;
                        expt_numInvalid_RoomProbe_CR = expt_numInvalid_RoomProbe_CR +1;
                    end
                end
           
        end
  
        % calculate cumulative H/M/CR/FAR
        
            % control valid                        
                cntrl_valid_ArtProbe_HitRate = cntrl_numValid_ArtProbe_Hits/cntrl_numValid_ArtProbe_Present;
                cntrl_valid_ArtProbeMissRate = cntrl_numValid_ArtProbe_Misses/cntrl_numValid_ArtProbe_Present;
                cntrl_valid_ArtProbe_FARate = cntrl_numValid_ArtProbe_FA/cntrl_numValid_ArtProbe_Absent;
                cntrl_valid_ArtProbe_CRRate = cntrl_numValid_ArtProbe_CR/cntrl_numValid_ArtProbe_Absent;
                cntrl_valid_RoomProbeHitRate = cntrl_numValid_RoomProbe_Hits/cntrl_numValid_RoomProbe_Present;
                cntrl_valid_RoomProbeMissRate = cntrl_numValid_RoomProbe_Misses/cntrl_numValid_RoomProbe_Present;
                cntrl_valid_RoomProbe_FARate = cntrl_numValid_RoomProbe_FA/cntrl_numValid_RoomProbe_Absent;
                cntrl_valid_RoomProbe_CRRate = cntrl_numValid_RoomProbe_CR/cntrl_numValid_RoomProbe_Absent;

            % control invalid    
                cntrl_invalid_ArtProbeHitRate = cntrl_numInvalid_ArtProbe_Hits/cntrl_numInvalid_ArtProbe_Present;
                cntrl_invalid_ArtProbeMissRate = cntrl_numInvalid_ArtProbe_Misses/cntrl_numInvalid_ArtProbe_Present;
                cntrl_invalid_ArtProbe_FARate = cntrl_numInvalid_ArtProbe_FA/cntrl_numInvalid_ArtProbe_Absent;
                cntrl_invalid_ArtProbe_CRRate = cntrl_numInvalid_ArtProbe_CR/cntrl_numInvalid_ArtProbe_Absent;
                cntrl_invalid_RoomProbeHitRate = cntrl_numInvalid_RoomProbe_Hits/cntrl_numInvalid_RoomProbe_Present;
                cntrl_invalid_RoomProbeMissRate = cntrl_numInvalid_RoomProbe_Misses/cntrl_numInvalid_RoomProbe_Present;
                cntrl_invalid_RoomProbe_FARate = cntrl_numInvalid_RoomProbe_FA/cntrl_numInvalid_RoomProbe_Absent;
                cntrl_invalid_RoomProbe_CRRate = cntrl_numInvalid_RoomProbe_CR/cntrl_numInvalid_RoomProbe_Absent;

             % experimental valid
                 expt_valid_ArtProbe_HitRate = expt_numValid_ArtProbe_Hits/expt_numValid_ArtProbe_Present;
                 expt_valid_ArtProbeMissRate = expt_numValid_ArtProbe_Misses/expt_numValid_ArtProbe_Present;
                 expt_valid_ArtProbe_FARate = expt_numValid_ArtProbe_FA/expt_numValid_ArtProbe_Absent;
                 expt_valid_ArtProbe_CRRate = expt_numValid_ArtProbe_CR/expt_numValid_ArtProbe_Absent;
                 expt_valid_RoomProbeHitRate = expt_numValid_RoomProbe_Hits/expt_numValid_RoomProbe_Present;
                 expt_valid_RoomProbeMissRate = expt_numValid_RoomProbe_Misses/expt_numValid_RoomProbe_Present;
                 expt_valid_RoomProbe_FARate = expt_numValid_RoomProbe_FA/expt_numValid_RoomProbe_Absent;
                 expt_valid_RoomProbe_CRRate = expt_numValid_RoomProbe_CR/expt_numValid_RoomProbe_Absent;

            % experimental invalid
                expt_invalid_ArtProbeHitRate = expt_numInvalid_ArtProbe_Hits/expt_numInvalid_ArtProbe_Present;
                expt_invalid_ArtProbeMissRate = expt_numInvalid_ArtProbe_Misses/expt_numInvalid_ArtProbe_Present;
                expt_invalid_ArtProbe_FARate = expt_numInvalid_ArtProbe_FA/expt_numInvalid_ArtProbe_Absent;
                expt_invalid_ArtProbe_CRRate = expt_numInvalid_ArtProbe_CR/expt_numInvalid_ArtProbe_Absent;
                expt_invalid_RoomProbeHitRate = expt_numInvalid_RoomProbe_Hits/expt_numInvalid_RoomProbe_Present;
                expt_invalid_RoomProbeMissRate = expt_numInvalid_RoomProbe_Misses/expt_numInvalid_RoomProbe_Present;
                expt_invalid_RoomProbe_FARate = expt_numInvalid_RoomProbe_FA/expt_numInvalid_RoomProbe_Absent;
                expt_invalid_RoomProbe_CRRate = expt_numInvalid_RoomProbe_CR/expt_numInvalid_RoomProbe_Absent;
                    
           
        
 %% save some data before moving on to next trial           
         Screen(mainWindow,'FillRect',backColor);
         Screen('Flip',mainWindow);
         FlushEvents('keyDown');
        
        % save data in txt file 
            % heading for reference: fprintf(dataFile,'trial\tstimOnsetTime\texptCond\tstimNum\tcue\tprobe\tvalid\tresp\tcorResp\tAcc\tRT\te_VArtH\te_VArtFA\te_VRoomH\te_VRoomFA\te_IVArtH\te_IVArtFA\te_IVRoomH\te_IVRoomFA\tc_VArtH\tc_VArtFA\tc_VRoomH\tc_VRoomFA\tc_IVArtH\tc_IVArtFA\tc_IVRoomH\tc_IVRoomFA\n')
            fprintf(dataFile,'%d\t%.3f\t\t%d\t\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.3f\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t\n',...
                trial, trialStartTime - startExptTime, tmpExptCond, tmpStim, tmpCueType, tmpProbeType, tmpCueValidity, thisResponse, tmpCorrectResponse, thisAcc, thisRT,...
                expt_valid_ArtProbe_HitRate, expt_valid_ArtProbe_FARate, expt_valid_RoomProbeHitRate, expt_valid_RoomProbe_FARate,...
                expt_invalid_ArtProbeHitRate, expt_invalid_ArtProbe_FARate, expt_invalid_RoomProbeHitRate, expt_invalid_RoomProbe_FARate,...
                cntrl_valid_ArtProbe_HitRate, cntrl_valid_ArtProbe_FARate, cntrl_valid_RoomProbeHitRate, cntrl_valid_RoomProbe_FARate,...
                cntrl_invalid_ArtProbeHitRate, cntrl_invalid_ArtProbe_FARate, cntrl_invalid_RoomProbeHitRate, cntrl_invalid_RoomProbe_FARate);
            
       % print to command window
            fprintf('%d\t%.3f\t\t%d\t\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.3f\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f\t\t\n',...
                trial, trialStartTime - startExptTime, tmpExptCond, tmpStim, tmpCueType, tmpProbeType, tmpCueValidity, thisResponse, tmpCorrectResponse, thisAcc, thisRT,...
                expt_valid_ArtProbe_HitRate, expt_valid_ArtProbe_FARate, expt_valid_RoomProbeHitRate, expt_valid_RoomProbe_FARate,...
                expt_invalid_ArtProbeHitRate, expt_invalid_ArtProbe_FARate, expt_invalid_RoomProbeHitRate, expt_invalid_RoomProbe_FARate,...
                cntrl_valid_ArtProbe_HitRate, cntrl_valid_ArtProbe_FARate, cntrl_valid_RoomProbeHitRate, cntrl_valid_RoomProbe_FARate,...
                cntrl_invalid_ArtProbeHitRate, cntrl_invalid_ArtProbe_FARate, cntrl_invalid_RoomProbeHitRate, cntrl_invalid_RoomProbe_FARate);
        
        % save(filename);
      
        end % trial loop
    
%% end of experiment
    % accuracyPercentage = (accuracy/(totalNumTrials/numBlocks*block))*100;
                        % this is for calculating cumulative accuracy across all experiment 'chunks'
                        % if you want to do this, don't reset accuracy to 0 before each chunk
    accuracyPercentage = (accuracy/(totalNumTrials/numBlocks))*100;

    instructString = ['Your accuracy for this set of trials was ' num2str(accuracyPercentage) '%'];
    boundRect = Screen('TextBounds', mainWindow, instructString);
    Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5-60, textColor);
    

    instructString = 'You''re finished! Thank you.';
    boundRect = Screen('TextBounds', mainWindow, instructString); 
    Screen('drawtext',mainWindow,instructString, centerX-boundRect(3)/2, centerY-boundRect(4)/5, textColor);
    Screen('Flip',mainWindow);

    WaitSecs(10);

    save(filename, 'stim', 'expt*Rate', 'cntrl*Rate');
    ListenChar(1);
    ShowCursor;
    fclose('all');
    Screen('CloseAll');
    clear Screen;
    
    
            
% po(ID,rew=0|1,[RTwin]) - popout Task rewarded block or not
%%% Examples
% po('Test',1)     --"quest"   find optimal RT window
% po('Test',1,.54) --"reward"  use optimal RT window in rewarded block      
% po('Test',0,.54) --"neutral" use optimal RT window in sensory-motor block 
% po('Test',0)     --"cruel"   NOT ALLOWED -- quest without feedback
function subj = pop(varargin) % pop(ID,rew?,RTwin)

    %% Parse input   
    % REWARD OR NEUTRAL
    % Quest or no Quest
    if ~isempty(varargin)
        ID = varargin{1};
        rewblock=varargin{2}; % 0 or 1
        
        %not practice, know ideal RT
        if(length(varargin)>2)
            baseRT = varargin{3};
            runQuest=0;
            %totalTrl=4;
            fprintf('not questing\n');
            
        % is practice, finding RT
        else
            fprintf('questing!\n');
            baseRT=.5;
            runQuest=1;
        end

    else
        % not practice, have an RT
        error('usage: pop(ID,rew,RTwin)');
    end
    
    % determin runtype, dont allow quest+neutral
    if runQuest
        runtype='quest';
        if ~rewblock
            error('you are running quest without rewards. Make your 0 a 1')
        end
    elseif rewblock
        runtype='reward';
    else
        runtype='neutralIncong';
    end
    
    % record things (saved later)
    subj.runtype=runtype;
    subj.id=ID;
    
    %% PTB SETUP
    s = popSettings();

    % setup the screen, font size and blending
    w=setupScreen(s.screen.bgColor,s.screen.res);

    % get textures from images (persistent in fuction)
    event_Fbk(w,[],[],[]);
    % similair for sounds, also initialize psych sounds;
    playSnd(); 
    
    
    
    %% Setup events
    % uses either readEvents or setupEvents dep. on quest and rew
    [eList, manips] = getEvents(rewblock,runQuest);
    %  eList like:  {trl,@func,eventname,starttime, endtime, args};
    
    instructions(w);
    
    startime=GetSecs();
    trialInfo=struct(); % we'll build trial info without output of each event
    
    % expected RT for 80% correct

    RT = questRTshift(baseRT,[],[]);
    RTshift = 0;

    %% get where to start and end
    % what events are we running
    firstEvent=1; 
    lastEvent=length(eList);
    
    
    %% go through each event we are running
    for eidx=firstEvent:lastEvent
        
        %% EVENT INFO
        evt=eList{eidx}; 
        % eList for this event has all the info we need to display an event
        trl= evt{1};     % which trial the event is a part of
        func=evt{2};     % the function to use for this event
        eName=evt{3};    % the name of the event
        estart=evt{4}+startime; % this is cum time start
                                % unless RSP, then it's max of RT window
        params=evt(6:length(evt)); % parameters to pass to the event func

        
        
        %% EVENT SPECIFIC CONSIDERATIONS
        % * feedback depend on if Rsp was correct or not
        % - Probe (colors square) should always be cong in neutral
        %    handled by input
        % - Cue no longer needs to be scaled by performance
        
                
        % Fbk needs correct value, and if this is quest
        if strncmp(eName,'Fbk',3)
           %if trl>1
               prevRTs= arrayfun(  @(x) x.Rsp.RT,   trialInfo(1:trl)  );
               muRT=mean(prevRTs(isfinite(prevRTs)));
               fprintf('RT: %.03f mean: %.03f\n', trialInfo(trl).Rsp.RT,muRT);
           %else
           %    muRT=0;
           %end
           
           % are we just a little faster than our mean?
           perf= trialInfo(trl).Rsp.RT <  muRT -0.05;
           subj.bonused(trl)=perf; % record to subject info
           
           estart=GetSecs(); % start feedback right away (after Rsp)
           
           % establish per trial params for feedback function
           params = [ params, runQuest==0, {trialInfo(trl).Rsp.correct}, perf ];  
        end
        
        
        
        
        %% PRINT TIME
        nt=GetSecs();
        fprintf('\t%s @ %.2f \t %.3fs + %.3fs \n', ...
                eName, estart - startime, nt-startime, estart-nt);
        
            
        %% RUN EVENT
        % run the event and save struct output into nested struct array
        trialInfo(trl).(eName) = func(w, estart, params{:} );
        
        
        
        
        
        
          
        %% CALCULATIONS
        % set difficulty using # correct and if it was easy or not
        % NOTE: this uses only between firstEvent and trl
        %       no support for an initial setting

        if trl>firstEvent && trl ~= eList{eidx-1}{1}
           fprintf('%d trl\n',trl);
           
           %%RT manipulation
           wasEasy = manips.val(trl-1,manips.easyIdx);
           if ~wasEasy
             wasCorrect = trialInfo(trl-1).Rsp.correct;
             RT=questRTshift(RT,wasCorrect,runQuest);
             RTshift = RT - baseRT;
             fprintf('\tnew RT: %.2f, %.2f diff than base\n',RT,RTshift);
           end
           
           %shift following events by RTs
           nxt=eidx+1;
           while nxt<=lastEvent && eList{nxt}{1} == trl 
                             
               if  any( strcmp(eList{nxt}{3}, {'Rsp','Fbk','ITI'}) )
                   eList{nxt}{4} = eList{nxt}{4} + RTshift;
               end
               
               % add again to make ITI shorter and keep Fbk the same
               if  any( strcmp(eList{nxt}{3}, {'ITI'}) )
                   eList{nxt}{4} = eList{nxt}{4} + RTshift;
               end
               
               nxt=nxt+1;
           end
           
           trialInfo(trl).RTshift   = RTshift;
           
        end
        
    end
    
    %% SAVE AT END
    subj.start      = startime;
    subj.trialInfo  = trialInfo;
    subj.events     = eList;
    subj.manips     = manips;
    subj.idealRTwin = baseRT + trialInfo(end).RTshift;
    
    
    
    
    fname=['subj/' ID '_'  runtype '_' date '_' num2str(now) '.mat'];
    save(fname,'-struct','subj' );
    
    
    %% draw done screen
    DrawFormattedText(w,'Thanks For Playing','center','center',[ 0 0 0 ]);
    Screen('Flip',w);
    KbWait;
    
    %% finish up
    closedown();
    if strncmp(runtype,'quest',5)
     plotResults(subj);
    else
     scorePop(fname)
    end
    
    fprintf('====\nideal RT: %.3f\n===\n',subj.idealRTwin);

end

%% get easy and correct logical lists from responses and manipulations
% will be used to manipulate trial difficulty
function [isEasy,isCorrect] = getEasyAndCorrect(firstEvent, trl,trialInfo,manips)
       isEasy = manips.val(firstEvent:(trl-1), manips.easyIdx);

       % list of correct or incorrect
       isCorrect = cellfun(@(x) x.correct,...
                           {trialInfo(firstEvent:(trl-1)).Rsp})>0;
end


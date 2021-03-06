% po(rew=0|1) - popout Task rewarded block or not
function subj = po_RTpreshift(varargin) 
    screenResolution=[1600 1200];
    backgroundColor=256/2*[1 1 1];

    % setup the screen, font size and blending
    w=setupScreen(backgroundColor,screenResolution);

    % get textures from images (persistent in fuction)
    event_Fbk(w,[],[],[]);
    % similair for sounds, also initialize psych sounds;
    playSnd(); 
    
    
    % total number of trials

    %totalTrl=2;
    
    if ~isempty(varargin)
        ID = varargin{1};
        rewblock=varargin{2}; % 0 or 1
        
        %not practice, know ideal RT
        if(length(varargin)>2)
            baseRTwait = varargin{3};
            runQuest=0;
            totalTrl=68;
            %totalTrl=4;
            fprintf('not questing\n');
            
        % is practice, finding RT
        else
            fprintf('questing!\n');
            baseRTwait=.3;
            runQuest=1;
            totalTrl=200;
        end

    else
        
        ID=[ date '_' num2str(now) ];
        rewblock=1;
        % not practice, have an RT
        error('give me some input');
    end
    % event list -- event_ITI event_Prp event_Cue event_Rsp event_Fbk 
    [eList, manips] = setupEvents(totalTrl,rewblock);
    %  {trl,@func,eventname,starttime, endtime, args};
      
    % expected RT for 80% correct

    RTwait = questRTshift(baseRTwait,[],[]);

    %% get where to start and end
    % what events are we running
    firstEvent=1; 
    lastEvent=length(eList);
    
    
    %% instructions
    instructions(w);
  
    
    trialInfo=struct(); % we'll build trial info without output of each event
    startime=GetSecs();
 
    %% go through each event we are running
    for eidx=firstEvent:lastEvent
        
        %% name event variables
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
        % * Cue no longer needs to be scaled by performance
        
                
        % Fbk needs correct value
        if strmatch(eName,'Fbk')
           estart=GetSecs(); % start feedback right away (after Rsp)
           params = [ params, {trialInfo(trl).Rsp.correct} ]; 
        
        % Rsp needs go offset and congruent?
        elseif strmatch(eName,'Rsp') 
           goCueOnset = trialInfo(trl).Cue.ideal+RTwait;
           dir = trialInfo(trl).Cue.dir;
           params = [ params,{ goCueOnset dir}  ]; 
        end
        
        
        %% the actual event
        % run the event and save struct output into nested struct array
        trialInfo(trl).(eName) = func(w, estart, params{:} );
          
        %% per trial calculations
        % set difficulty using # correct and if it was easy or not
        % NOTE: this uses only between firstEvent and trl
        %       no support for an initial setting

        if trl>firstEvent && trl ~= eList{eidx-1}{1}
           fprintf('%d trl\n',trl);
           
           %%RT manipulation
           wasEasy = manips.val(trl-1,manips.easyIdx);
           if ~wasEasy
             wasCorrect = trialInfo(trl-1).Rsp.correct;
             RTwait=questRTshift(RTwait,wasCorrect,runQuest);
             fprintf('\tnew RTwait: %.2f vs %.2f diff than base\n',RTwait,baseRTwait);
           end
           
           %shift following events by RTs
           nxt=eidx+1;
           while nxt<=lastEvent && eList{nxt}{1} == trl 
                             
               if  any( strcmp(eList{nxt}{3}, {'Rsp','Fbk','ITI'}) )
                   eList{nxt}{4} = eList{nxt}{4} + RTwait;
               end
               
               % add again to make ITI shorter and keep Fbk the same
               if  any( strcmp(eList{nxt}{3}, {'ITI'}) )
                   eList{nxt}{4} = eList{nxt}{4} + RTwait;
               end
               
               nxt=nxt+1;
           end
           
           trialInfo(trl).RTshift   = RTwait;
           
        end
        
    end
    
    %% stuff to save
    subj.trialInfo = trialInfo;
    subj.events = eList;
    subj.manips = manips;
    subj.idealRTwin = baseRTwait + trialInfo(end).RTshift;
    save([ID '.mat'],'-struct','subj' );
    
    
    %% draw done screen
    DrawFormattedText(w,'Thanks For Playing','center','center',[ 0 0 0 ]);
    Screen('Flip',w);
    KbWait;
    
    %% finish up
    closedown();
    plotResults(subj);
    
    fprintf('====\nideal RT: %.3f\n===\n',subj.idealRTwin);

end


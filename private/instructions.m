function instructions(w)
    instructions = {[
         'Push the button pointed to by the arrow,\n' ...
         'unless the box is red. Then do the opposite.\n' ...
         '1 = left\n0=right' ...
         'Too slow will be incorrect!']};
    i=1;
    DrawFormattedText(w,instructions{i},'center','center',[ 0 0 0 ]);
    Screen('Flip',w);
    KbWait;
end

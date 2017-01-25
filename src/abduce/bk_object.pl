% background knowledge for abducing objects
%============================================================================

% circles, ellipses, polygons
% confidence level (mid-point evaluation)

min_error_dist_ratio(0.02).
min_error_prob(0.7).

:- ensure_loaded(['../utils/utils.pl']).

%====================
% object abduction
%====================
% ellipses
abduce_object_elps(Img, Model, Edge_Points, Obj):-
    length(Edge_Points, Num_Pts), Num_Pts =< 1,
    size_2d(Img, W, H),
    rand_line_2d([W, H], Pt, Dir),
    sample_line_color_L_hist_2d(Img, Pt, Dir, Line_Pts, Line_Hist),
    predict_svm(Model, Line_Hist, Line_Label),
    ((positive_segs(Line_Pts, Line_Label, PSegs),
      (random_select(PSegs, Seg))) -> % only use one seg
         (abduce_object_elps(Img, Model, Seg, Obj), !);
     (abduce_object_elps(Img, Model, [], Obj), !)).

abduce_object_elps(Img, Model, Edge_Points, Obj):-
    length(Edge_Points, Num_Pts),
    Num_Pts < 10, Num_Pts > 1, randset(2, Num_Pts, Indices),
    index_select1(Indices, Edge_Points, [P1, P2]),
    % randomly choose clockwise or inverse clockwise
    mid_point(P1, P2, P0),
    ((sample_middle_point(Img, Model, P0, P1, P2, P), P \= []) ->
               (abduce_object_elps(Img, Model, [P | Edge_Points], Obj), !);
     (list_delete(Edge_Points, [P1, P2], Edge_Points_1),
      abduce_object_elps(Img, Model, Edge_Points_1, Obj), !)
    ).

abduce_object_elps(Img, Model, Edge_Points, Obj):-
    length(Edge_Points, Num_Pts), Num_Pts >= 10,
    % if points are enough for fitting an ellipse
    fit_elps_2d(Edge_Points, Center, Parameters),
    reorder_points_clockwise(Center, Edge_Points, Edge_Points_1),
    eval_object_elps(Img, Model, Edge_Points_1, [Center, Parameters], Obj), !.

eval_object_elps(Img, Model, Edge_Points, [Center, Parameters], Obj):-
    Edge_Points = [First | Tail],
    append(Tail, [First], EP2),
    maplist(sample_middle_point(Img, Model, Center), Edge_Points, EP2, Sampled),
    maplist(dist_elps_point_2d([Center, Parameters]), Sampled, Distances),
    size_2d(Img, W, H),
    
    /*%% debug
    clone_img(Img, Img2),
    ellipse_points_2d(Center, Parameters, [W, H], ELPS),
    draw_points_2d(Img2, ELPS, red),
    draw_points_2d(Img2, Edge_Points, blue),
    draw_points_2d(Img2, Sampled, yellow),
    showimg_win(Img2, 'fit elps'),
    release_img(Img2),
    %% Debug end*/

    min_error_dist_ratio(Err_R), min_error_prob(Prob),
    Err is sqrt(W**2 + H**2)*Err_R,
    findall(D, (member(D, Distances), greater_than(Err, D)), Ds),
    length(Ds, Len), length(Distances, Tot),
    (Len/Tot >= Prob ->
         (Obj = elps(Center, Parameters), !);
     (last(Sampled, SP), append([SP], Sampled, Sampled1),
      last(Distances, DS), append([DS], Distances, Distances1),
      remove_failed_points(Edge_Points, Sampled1, Distances1, Err, Trusted),
      abduce_object_elps(Img, Model, Trusted, Obj))
    ), !.

% circle
abduce_object_circle(Img, Model, Edge_Points, Obj):-
    length(Edge_Points, Num_Pts), Num_Pts =< 1,
    size_2d(Img, W, H),
    rand_line_2d([W, H], Pt, Dir),
    sample_line_color_L_hist_2d(Img, Pt, Dir, Line_Pts, Line_Hist),
    predict_svm(Model, Line_Hist, Line_Label),
    ((positive_segs(Line_Pts, Line_Label, PSegs),
      (random_select(PSegs, Seg))) -> % only use one seg
         (abduce_object_circle(Img, Model, Seg, Obj), !);
     (abduce_object_circle(Img, Model, [], Obj), !)).

abduce_object_circle(Img, Model, Edge_Points, Obj):-
    length(Edge_Points, Num_Pts),
    Num_Pts < 3, Num_Pts > 1, randset(2, Num_Pts, Indices),
    index_select1(Indices, Edge_Points, [P1, P2]),
    % randomly choose clockwise or inverse clockwise
    mid_point(P1, P2, P0),
    ((sample_middle_point_between(Img, Model, P0, P1, P2, P), P \= []) ->
               (abduce_object_circle(Img, Model, [P | Edge_Points], Obj), !);
     (list_delete(Edge_Points, [P1, P2], Edge_Points_1),
      abduce_object_circle(Img, Model, Edge_Points_1, Obj), !)
    ).

abduce_object_circle(Img, Model, Edge_Points, Obj):-
    length(Edge_Points, Num_Pts), Num_Pts >= 3,
    % if points are enough for fitting an ellipse
    fit_circle_2d(Edge_Points, Center, Radius),
    reorder_points_clockwise(Center, Edge_Points, Edge_Points_1),
    eval_object_circle(Img, Model, Edge_Points_1, [Center, Radius], Obj), !.

eval_object_circle(Img, Model, Edge_Points, [Center, Radius], Obj):-
    Edge_Points = [_ | Tail], append(Head, [_], Edge_Points), !,
    maplist(eval_middle_point(Img, Model, circle(Center, Radius)),
            Head, Tail, Sampled),
    maplist(dist_circle_point_2d([Center, Radius]), Sampled, Distances),
    size_2d(Img, W, H),
    
    /*%% debug
    clone_img(Img, Img2),
    circle_points_2d(Center, Radius, [W, H], CIRCLE),
    draw_points_2d(Img2, CIRCLE, red),
    draw_points_2d(Img2, Edge_Points, blue),
    draw_points_2d(Img2, Sampled, yellow),
    showimg_win(Img2, 'fit elps'),
    release_img(Img2),
    %% Debug end */

    min_error_dist_ratio(Err_R), min_error_prob(Prob),
    Err is sqrt(W**2 + H**2)*Err_R,
    findall(D, (member(D, Distances), greater_than(Err, D)), Ds),
    length(Ds, Len), length(Distances, Tot),
    (Len/Tot >= Prob ->
         (Obj = circle(Center, Radius), !);
     (append(Edge_Points1, [_], Tail), !,
      remove_failed_points(Edge_Points1, Sampled, Distances, Err, Trusted0),
      Sampled = [S0 | _], append([S0], Trusted0, Trusted1),
      list_to_set(Trusted1, Trusted),
      abduce_object_circle(Img, Model, Trusted, Obj))
    ), !.

% remove the points failing the evaluation
remove_failed_points([], [_], [_], _, []):-
    !.
remove_failed_points([EP | Edge_Points],
                     [_, S2 | Sampled], [D1, D2 | Distances], Err,
                     [T | Trusted]):-
    D1 =< Err, D2 =< Err, T = EP,
    remove_failed_points(Edge_Points,
                         [S2 | Sampled], [D2 | Distances], Err, Trusted), !.
remove_failed_points([_ | Edge_Points],
                     [_, S2 | Sampled], [_, D2 | Distances], Err,
                     [T | Trusted]):-
    S2 \= [], T = S2,
    remove_failed_points(Edge_Points,
                         [S2 | Sampled], [D2 | Distances], Err, Trusted), !.
remove_failed_points([_ | Edge_Points],
                     [_, S2 | Sampled], [_, D2 | Distances], Err,
                     Trusted):-
    S2 = [],
    remove_failed_points(Edge_Points,
                         [S2 | Sampled], [D2 | Distances], Err, Trusted), !.

% may sample clockwise or inverse clockwise
sample_middle_point(Img, Model, Center, P1_, P2_, Edge_Point):-
    (maybe(0.5) -> (P1 = P2_, P2 = P1_); (P1 = P1_, P2 = P2_)), !,
    vec_diff(P1, Center, D1),
    vec_diff(P2, Center, D2),
    vec_rotate_angle_clockwise(D1, D2, Ang1), Ang is Ang1/2,
    turn_degree_2d(D1, Ang, Dir),
    sample_ray_color_L_hist_2d(Img, Center, Dir, Ray_Pts, Ray_Hist),
    ((predict_svm(Model, Ray_Hist, Ray_Label),
      Ray_Label = [1, 1, 1 | _],
      positive_segs(Ray_Pts, Ray_Label, Segs),
      crossed_segs_2d(Center, Segs, [[Center, EP] | _])) ->
         Edge_Point = EP;
     Edge_Point = []), !.

sample_middle_point_between(Img, Model, Center, P1_, P2_, Edge_Point):-
    (maybe(0.5) -> (P1 = P2_, P2 = P1_); (P1 = P1_, P2 = P2_)), !,
    vec_diff(P1, Center, D1),
    vec_diff(P2, Center, D2),
    vec_rotate_angle(D1, D2, Ang1), Ang is Ang1/2,
    turn_degree_2d(D1, Ang, Dir),
    sample_ray_color_L_hist_2d(Img, Center, Dir, Ray_Pts, Ray_Hist),
    ((predict_svm(Model, Ray_Hist, Ray_Label),
      %Ray_Label = [1, 1, 1 | _],
      positive_segs(Ray_Pts, Ray_Label, Segs),
      Segs = [[_, EP] | _]) ->
         Edge_Point = EP;
     Edge_Point = []), !.

eval_middle_point(Img, Model, circle(Cen, Rad), P1_, P2_, Edge_Point):-
    (maybe(0.001) -> (P1 = P2_, P2 = P1_); (P1 = P1_, P2 = P2_)), !,
    vec_diff(P1, Cen, D1),
    vec_diff(P2, Cen, D2),
    vec_rotate_angle(D1, D2, Ang1), Ang is Ang1/2,
    turn_degree_2d(D1, Ang, Dir),
    vec_sum(Cen, Dir, Sum),
    sample_ray_color_L_hist_2d(Img, Cen, Dir, Ray_Pts, Ray_Hist),
    ((predict_svm(Model, Ray_Hist, Ray_Label),
      positive_segs(Ray_Pts, Ray_Label, Segs),
      dist_point_circle_2d(Sum, [Cen, Rad], _, EP),
      column(2, Segs, Ends),
      closest_point_in_list(EP, Ends, P)) ->
         Edge_Point = P;
     Edge_Point = []), !.

/*
eval_middle_point(Img, Model, elps(Cen, Param), P1_, P2_, Edge_Point):-
    (maybe(0.5) -> (P1 = P2_, P2 = P1_); (P1 = P1_, P2 = P2_)), !,
    vec_diff(P1, Center, D1),
    vec_diff(P2, Center, D2),
    vec_rotate_angle(D1, D2, Ang1), Ang is Ang1/2,
    turn_degree_2d(D1, Ang, Dir),
    % TODO::: to be optimized, x/y = sin/cos(theta)*k, solve equation
    size_2d(Img, W, H),
    sample_ray_color_L_hist_2d(Img, Center, Dir, Ray_Pts, Ray_Hist),
    ellipse_points_2d(Cen, Para, [W, H], Elps_Pts),
    ((predict_svm(Model, Hist, Ray_Label),
      intersection(Ray_Pts, Elps_Pts, [EP | _]),
      pts_color_hists_2d(Img, [EP], Hist)) ->
         Edge_Point = EP;
     Edge_Point = []), !.
*/

% reorder the points (Pts_) w.r.t. a origin P0 clockwise
reorder_points_clockwise(P0, Pts_, Re):-
    list_to_set(Pts_, Pts),
    maplist(vec_neg_diff(P0), Pts, Dirs),
    maplist(vec_rotate_angle_clockwise([0, -1]), Dirs, Angs),
    pairs_keys_values(Pairs, Angs, Pts),
    keysort(Pairs, Sorted),
    pairs_keys_values(Sorted, _, Re).

crossed_segs_2d(_, [], []):-
    !.
crossed_segs_2d([X, Y], [S | Ss], [S | CSs]):-
    S = [[X1, Y1], [X2, Y2]],
    ((between(X1, X2, X); between(X2, X1, X)),
     (between(Y1, Y2, Y); between(Y2, Y1, Y))), !,
    crossed_segs_2d([X, Y], Ss, CSs).
crossed_segs_2d(P, [_ | Ss], CSs):-
    crossed_segs_2d(P, Ss, CSs).

%=======================================================================
% given an item sequence and a label (0-negative, 1-positive) sequence,
% get the subsequences that are + (1s)
%=======================================================================
positive_segs(Pts, Labels, Return):-
    positive_segs(Pts, Labels, out, nil, Return).
% positive_seg(Pts, Labels, In/Out, Tmp_Start, Return)
positive_segs([], [], _, _, []):-
    !.
positive_segs([_, _  | Pts], [1, 0 | Labels], out, nil, Re):-
    positive_segs(Pts, Labels, out, nil, Re), !.
positive_segs([_, _, _ | Pts], [1, 1, 0 | Labels], out, nil, Re):-
    positive_segs(Pts, Labels, out, nil, Re), !.
positive_segs([_, _, _, _ | Pts], [1, 1, 1, 0 | Labels], out, nil, Re):-
    positive_segs(Pts, Labels, out, nil, Re), !.
positive_segs([P | Pts], [1 | Labels], out, nil, Re):-
    positive_segs(Pts, Labels, in, P, Re), !.
positive_segs([_ | Pts], [0 | Labels], out, nil, Re):-
    positive_segs(Pts, Labels, out, nil, Re), !.
positive_segs([_, _ | Pts], [0, 1 | Labels], in, Tmp_Start, Re):-
    positive_segs(Pts, Labels, in, Tmp_Start, Re), !.
positive_segs([_, _, _ | Pts], [0, 0, 1 | Labels], in, Tmp_Start, Re):-
    positive_segs(Pts, Labels, in, Tmp_Start, Re), !.
positive_segs([_, _, _, _ | Pts], [0, 0, 0, 1 | Labels], in, Tmp_Start, Re):-
    positive_segs(Pts, Labels, in, Tmp_Start, Re), !.
positive_segs([P | Pts], [0 | Labels], in, Tmp_Start, [R | Re]):-
    R = [Tmp_Start, P],
    positive_segs(Pts, Labels, out, nil, Re).
positive_segs([_ | Pts], [1 | Labels], in, Tmp_Start, Re):-
    positive_segs(Pts, Labels, in, Tmp_Start, Re), !.

%======================================
% train statistical model
%======================================
train_stat_model_protist(Model):-
    time(gen_pts_train_data('../../data/Protist0.png',
                            '../../data/Protist0_fg.bmp',
                            200, Data_Label_1)),
    %print_list_ln(Data_Label),
    subsample(1.0, 0.3, Data_Label_1, Data_Label),
    write("Training SVM: "),
    time(train_svm(Data_Label,
                   '-g 0.0039 -c 100000 -h 0',
                   Model)),
    writeln("Training SVM complete!"),
    save_model_svm(Model, '../../tmp/SVM_Protist.model').
train_stat_model_moon(Model):-
    time(gen_pts_train_data('../../data/Moon0.jpg',
                            '../../data/Moon0_fg.bmp',
                            50, Data_Label_1)),
    time(gen_pts_train_data('../../data/Moon1.jpg',
                            '../../data/Moon1_fg.bmp',
                            50, Data_Label_2)),
    time(gen_pts_train_data('../../data/Moon2.jpg',
                            '../../data/Moon2_fg.bmp',
                            50, Data_Label_3)),
    time(gen_pts_train_data('../../data/Moon3.jpg',
                            '../../data/Moon3_fg.bmp',
                            50, Data_Label_4)),
    time(gen_pts_train_data('../../data/Moon4.jpg',
                            '../../data/Moon4_fg.bmp',
                            50, Data_Label_5)),
    time(gen_pts_train_data('../../data/Moon5.jpg',
                            '../../data/Moon5_fg.bmp',
                            50, Data_Label_6)),
    %print_list_ln(Data_Label),
    append([Data_Label_1, Data_Label_2, Data_Label_3, Data_Label_4, Data_Label_5, Data_Label_6], Data_Labels),
    subsample(1.0, 0.7, Data_Labels, Data_Label),
    write("Training SVM: "),
    time(train_svm(Data_Label, '-g 0.0039 -c 100000 -h 0', Model)),
    writeln("Training SVM complete!"),
    save_model_svm(Model, '../../tmp/SVM_Moon.model').

%=========================
% cut object into 2 halves
%=========================
% get the splited points
% clock angle \in [0, 11]
split_ellipse(Img, elps(Cen, Param), Clock_Ang, Front, Rear):-
    size_2d(Img, W, H),
    get_points_in_ellipse_2d([Cen, Param], [W, H], Points),
    Theta is (Clock_Ang mod 12)*30*pi/180,
    DX is cos(Theta), DY is sin(Theta),
    findall(P,
            (member(P, Points),
             vec_diff(P, Cen, D),
             cross([DX, DY], D, C),
             C < 0),
            Front
           ),
    findall(P,
            (member(P, Points),
             vec_diff(P, Cen, D),
             cross([DX, DY], D, C),
             C > 0),
            Rear
           ).

split_circle(Img, circle(Cen, Rad), Clock_Ang, Front, Rear):-
    size_2d(Img, W, H),
    get_points_in_circle_2d([Cen, Rad], [W, H], Points),
    Theta is (Clock_Ang mod 12)*30*pi/180,
    DX is cos(Theta), DY is sin(Theta),
    findall(P,
            (member(P, Points),
             vec_diff(P, Cen, D),
             cross([DX, DY], D, C),
             C < 0),
            Front
           ),
    findall(P,
            (member(P, Points),
             vec_diff(P, Cen, D),
             cross([DX, DY], D, C),
             C > 0),
            Rear
           ).

%===================================
% find largest contrast direction
%===================================
get_largest_contrast_angle(Img, Obj, Re):-
    get_largest_contrast_angle(Img, Obj, 12, -1, -1000, Re).
get_largest_contrast_angle(_, _, 0, Re, _, Re):-
    !.
get_largest_contrast_angle(Img, elps(C, P), Ang, Tmp_Ang, Tmp, Re):-
    Ang1 is Ang - 1,
    split_ellipse(Img, elps(C, P), Ang, Front, Rear),
    pts_color_L_avg_2d(Img, Front, Bright_F),
    pts_color_L_avg_2d(Img, Rear, Bright_R),
    Diff is Bright_F - Bright_R,
    (Diff > Tmp ->
         (get_largest_contrast_angle(Img, elps(C, P), Ang1, Ang, Diff, Re), !);
     (get_largest_contrast_angle(Img, elps(C, P), Ang1, Tmp_Ang, Tmp, Re), !)
    ).
get_largest_contrast_angle(Img, circle(C, R), Ang, Tmp_Ang, Tmp, Re):-
    Ang1 is Ang - 1,
    split_circle(Img, circle(C, R), Ang, Front, Rear),
    pts_color_L_avg_2d(Img, Front, Bright_F),
    pts_color_L_avg_2d(Img, Rear, Bright_R),
    Diff is Bright_F - Bright_R,
    (Diff > Tmp ->
         (get_largest_contrast_angle(Img, circle(C, R), Ang1, Ang, Diff, Re), !);
     (get_largest_contrast_angle(Img, circle(C, R), Ang1, Tmp_Ang, Tmp, Re), !)
    ).


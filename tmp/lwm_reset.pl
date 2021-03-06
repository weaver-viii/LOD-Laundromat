:- module(
  lwm_reset,
  [
    reset_datadoc/1 % +Datadoc:iri
  ]
).

/** <module> LOD Washing Machine: Reset

Reset data documents in the triple store.

@author Wouter Beek
@version 2016/01
*/

:- use_module(library(apply)).
:- use_module(library(dcg/basics)).
:- use_module(library(debug)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(settings)).
:- use_module(library(thread)).
:- use_module(library(uri)).

:- rdf_meta
   reset_datadoc(r).





%! reset_datadoc(+Datadoc:iri) is det.

% Make sure the input is indeed a data document.
% Otherwise the entire graph may be removed.
reset_datadoc(Datadoc) :-
  % Make sure the MD5 is not empty.
  rdf_global_id(ll:Md5, Datadoc),
  atom_phrase(whites, Md5), !.
reset_datadoc(Datadoc) :-
  lwm_settings:setting(endpoint, both), !,
  reset_datadoc(virtuoso, Datadoc).
reset_datadoc(Datadoc) :-
  lwm_settings:setting(endpoint, Endpoint),
  reset_datadoc(Endpoint, Datadoc).


%! reset_datadoc(
%!   +Endpoint:oneof([cliopatria,virtuoso]),
%!   +Datadoc:atom
%! ) is det.
% @tbd Implement this by using the HTTP DELETE method on the datadoc URI.

reset_datadoc(cliopatria, Datadoc) :- !,
  sparql_endpoint_location(cliopatria, Uri0),
  uri_components(Uri0, uri_components(Scheme,Authority,_,_,_)),
  uri_query_components(Search, [datadoc=Datadoc]),
  uri_components(Uri,  uri_components(Scheme,Authority,'/reset',Search,_)),
  sparql_endpoint_option(cliopatria, authentication(update), Authentication),
  merge_options(
    [fail_on_status([404]),status_code(Status)],
    [Authentication],
    Options
  ),
  http_goal(Uri, true, Options),
  (   between(200, 299, Status)
  ->  true
  ;   debug(lwm, "[RESET FAILED] Status code ~d received.", [Status])
  ),
  print_message(informational, lwm_reset(Datadoc)).
reset_datadoc(virtuoso, Datadoc) :-
  lwm_version_graph(NG),
  datadoc_p_os(Datadoc, llo:warning, Warnings),
  forall(
    member(Warning, Warnings),
    (
      datadoc_p_os(Warning, error:streamPosition, StreamPositions),
      maplist(delete_resource(NG), StreamPositions)
    )
  ),
  maplist(delete_resource(NG), Warnings),
  delete_resource(NG, Datadoc),

  datadoc_directory(Datadoc, DatadocDir),
  (   absolute_file_name(data(.), DataDir, [file_type(directory)]),
      DatadocDir == DataDir
  ->  true
  ;   delete_directory_and_contents(DatadocDir),
      print_message(informational, lwm_reset(NG,Datadoc))
  ).





% HELPERS %

datadoc_directory(Datadoc, Dir) :-
  rdf_global_id(ll:Md5, Datadoc),
  md5_directory(Md5, Dir).



%! delete_resource(+Graph:atom, +Resource:rdf_term) is det.

delete_resource(Graph, Resource) :-
  sparql_delete_where(
    virtuoso_update,
    [],
    [rdf(Resource,var(p),var(o))],
    [Graph],
    [],
    []
  ).





% MESSAGES %

:- multifile(prolog:message//1).

prolog:message(lwm_reset(Datadoc)) -->
  ['Successfully reset ',Datadoc,'.'].
prolog:message(lwm_reset(NG,Datadoc)) -->
  ['Successfully reset ',Datadoc,' in graph ',NG,'.'].

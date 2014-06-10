:- module(
  lwm_store_triple,
  [
    store_archive_entries/3, % +Url:url
                             % +Md5:atom
                             % +Coordinates:list(list(nonneg))
    store_finished/1, % +Md5:atom
    store_http/4, % +Md5:atom
                  % ?ContentLength:nonneg
                  % ?ContentType:atom
                  % ?LastModified:nonneg
    store_lwm_start/1, % +Md5:atom
    store_message/2, % +Md5:atom
                     % +Message:compound
    store_status/2, % +Md5:atom
                    % +Status:or([boolean,compound]))
    store_source/2 % +Md5:atom
                   % +Source
  ]
).

/** <module> LOD Washing Machine: store triples

Temporarily store triples into the noRDF store.
Whenever a dirty item has been fully cleaned,
the stored triples are sent in a SPARQL Update request
(see module [noRdf_store].

@author Wouter Beek
@version 2014/04-2014/06
*/

:- use_module(library(aggregate)).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(semweb/rdf_db)).

:- use_module(pl(pl_control)).
:- use_module(pl(pl_log)).
:- use_module(xsd(xsd_dateTime_ext)).

:- use_module(lwm(lwm_db)).
:- use_module(lwm(lwm_generics)).
:- use_module(lwm(noRdf_store)).



%! store_archive_entries(+Url, +Md5:atom, +Coordinates:list(list(nonneg))) is det.

store_archive_entries(_, _, []):- !.
store_archive_entries(Url, Md5, Coords):-
  store_triple(lwm-Md5, rdf:type, lwm:'Archive', ap),
  maplist(store_archive_entry(Url, Md5), Coords).

store_archive_entry(Url, FromMd5, _):-
  source_to_md5(Url, ToMd5),
  store_triple(lwm-FromMd5, lwm:contains_entry, ToMd5, ap).


%! store_finished(+Md5:atom) is det.

store_finished(Md5):-
  get_dateTime(Now),
  store_triple(lwm-Md5, lwm:lwm_end, literal(type(xsd:dateTime,Now)), ap).


%! store_http(
%!   +Md5:atom,
%!   ?ContentLength:nonneg,
%!   ?ContentType:atom,
%!   ?LastModified:nonneg
%! ) is det.

store_http(Md5, ContentLength, ContentType, LastModified):-
  unless(
    ContentLength == '',
    store_triple(lwm-Md5, lwm:content_length,
        literal(type(xsd:integer,ContentLength)), ap)
  ),
  unless(
    ContentType == '',
    store_triple(lwm-Md5, lwm:content_type,
        literal(type(xsd:string,ContentType)), ap)
  ),
  % @tbd Store as xsd:dateTime
  unless(
    LastModified == '',
    store_triple(lwm-Md5, lwm:last_modified,
        literal(type(xsd:string,LastModified)), ap)
  ).


%! store_location_properties(+Url1:url, +Location:dict, -Url2:url) is det.

store_location_properties(Url1, Location, Url2):-
  (
    Data1 = Location.get(data),
    exclude(filter, Data1, Data2),
    last(Data2, ArchiveEntry)
  ->
    Name = ArchiveEntry.get(name),
    atomic_list_concat([Url1,Name], '/', Url2),
    store_triple(Url1, lwm:archive_contains, Url2, ap),
    ignore(store_triple(Url2, lwm:format,
        literal(type(xsd:string,ArchiveEntry.get(format))), ap)),
    ignore(store_triple(Url2, lwm:size,
        literal(type(xsd:integer,ArchiveEntry.get(size))), ap)),
    store_triple(Url2, rdf:type, lwm:'LOD-URL', ap)
  ;
    Url2 = Url1
  ),
  ignore(store_triple(Url2, lwm:http_content_type,
      literal(type(xsd:string,Location.get(content_type))), ap)),
  ignore(store_triple(Url2, lwm:http_content_length,
      literal(type(xsd:integer,Location.get(content_length))), ap)),
  ignore(store_triple(Url2, lwm:http_last_modified,
      literal(type(xsd:string,Location.get(last_modified))), ap)),
  store_triple(Url2, lwm:url, literal(type(xsd:string,Location.get(url))), ap),

  (
    location_base(Location, Base),
    file_name_extension(_, Ext, Base),
    Ext \== ''
  ->
    store_triple(Url2, lwm:file_extension, literal(type(xsd:string,Ext)), ap)
  ;
    true
  ).
filter(filter(_)).


%! store_lwm_start(+Md5:atom) is det.

store_lwm_start(Md5):-
  % Start date of processing by the LOD Washing Machine.
  get_dateTime(Now),
  store_triple(lwm-Md5, lwm:lwm_start, literal(type(xsd:dateTime,Now)), ap),

  % LOD Washing Machine version.
  lwm_version(Version),
  store_triple(lwm-Md5, lwm:lwm_version, literal(type(xsd:integer,Version)),
      ap),

  post_rdf_triples.


%! store_message(+Md5:atom, +Message:compound) is det.

store_message(Md5, Message):-
  with_output_to(atom(String), write_canonical_blobs(Message)),
  store_triple(lwm-Md5, lwm:message, literal(type(xsd:string,String)), ap).


%! store_number_of_triples(
%!   +Url:url,
%!   +Path:atom,
%!   +ReadTriples:nonneg,
%!   +WrittenTriples:nonneg
%! ) is det.

store_number_of_triples(Url, Path, TIn, TOut):-
  store_triple(Url, lwm:triples, literal(type(xsd:integer,TOut)), ap),
  TDup is TIn - TOut,
  store_triple(Url, lwm:duplicates, literal(type(xsd:integer,TDup)), ap),
  print_message(informational, rdf_ntriples_written(Path,TDup,TOut)).


%! store_status(+Md5:atom, +Status:or([boolean,compound])) is det.

store_status(Md5, Status):-
  with_output_to(atom(String), write_canonical_blobs(Status)),
  store_triple(lwm-Md5, lwm:status, literal(type(xsd:string,String)), ap).


%! store_stream_properties(+Url:url, +Stream:stream) is det.

store_stream_properties(Url, Stream):-
  stream_property(Stream, position(Position)),
  forall(
    stream_position_data(Field, Position, Value),
    (
      atomic_list_concat([stream,Field], '_', Name),
      rdf_global_id(lwm:Name, Predicate),
      store_triple(Url, Predicate, literal(type(xsd:integer,Value)), ap)
    )
  ).


%! store_source(+Md5:atom, +Source) is det.
% Store the given URL plus coordinate as one of the items
% that is cleaned by the LOD Washing Machine.
%
% This includes the following properties:
%   - LOD Washing Machine version
%   - Start datetime of processing by the LOD Washing Machine.
%   - Date and time at which the URL was added to the LOD Basket.

store_source(Md5Entry, Md5Url-EntryPath):- !,
  store_triple(lwm-Md5Entry, rdf:type, 'ArchiveEntry', ap),
  store_triple(lwm-Md5Entry, lwm:entry_path,
      literal(type(xsd:string,EntryPath)), ap),
  store_triple(lwm-Md5Url, lwm:has_archive_entry, lwm:Md5Entry, ap),
  store_source0(Md5Entry).
store_source(Md5, Url):-
  store_triple(lwm-Md5, rdf:type, lwm:'LOD-URL', ap),
  store_triple(lwm-Md5, lwm:url, Url, ap),
  store_source0(Md5).

store_source0(Md5):-
  % Md5.
  store_triple(lwm-Md5, lwm:md5, literal(type(xsd:string,Md5)), ap),

  % Datetime at which the URL was added to the LOD Basket.
  get_dateTime(Added),
  store_triple(lwm-Md5, lwm:added, literal(type(xsd:dateTime,Added)), ap).


%! store_void_triples(+DataDocument:url) is det.

store_void_triples(DataDocument):-
  aggregate_all(
    set(P),
    (
      rdf_current_predicate(P),
      rdf_global_id(void:_, P)
    ),
    Ps
  ),
  forall(
    (
      member(P, Ps),
      rdf(S, P, O)
    ),
    store_triple(S, P, O, DataDocument)
  ).

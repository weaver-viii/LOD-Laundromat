:- module(
  lwm_sparql_query,
  [
    datadoc_archive_entry/3, % +Datadoc:uri
                             % -ParentMd5:atom
                             % -EntryPath:atom
    datadoc_cleaning/1, % -Datadocs:list(iri))
    datadoc_content_type/2, % +Datadoc:uri
                            % -ContentType:atom
    datadoc_describe/2, % +Md5:atom
                        % -Triples:list(compound)
    datadoc_exists/1, % +Datadoc:uri
    datadoc_file_extension/2, % +Datadoc:uri
                              % -FileExtension:atom
    datadoc_has_triples/1, % +Datadoc:uri
    datadoc_source/2, % +Datadoc:uri
                      % -Source:atom
    datadoc_location/2, % +Datadoc:iri
                        % -Location:uri
    datadoc_unpacked_size/2, % +Datadoc:iri
                             % -UnpackedSize:nonneg
    datadoc_unpacking/1, % -Datadocs:list(iri))
    datadoc_p_os/3 % +Datadoc:iri
                   % +Property:iri
                   % -Objects:list(rdf_term)
  ]
).

/** <module> llWashingMachine: SPARQL query

SPARQL queries for retrieving specific properties of a data document
in the LOD Washing Machine.

@author Wouter Beek
@version 2014/06, 2014/08-2014/09, 2014/11, 2015/01-2015/02
*/

:- use_module(library(apply)).
:- use_module(library(lists), except([delete/3,subset/2])).

:- use_module(plRdf(term/rdf_literal)).

:- use_module(lwm(query/lwm_sparql_generics)).

:- rdf_meta(datadoc_p_os(r,r,-)).





%! datadoc_archive_entry(
%!   +Datadoc:uri,
%!   -ParentMd5:atom,
%!   -EntryPath:atom
%! ) is det.

datadoc_archive_entry(Datadoc, ParentMd5, EntryPath):-
  lwm_sparql_select(
    [llo],
    [parentMd5,entryPath],
    [
      rdf(Datadoc, llo:path, var(entryPath)),
      rdf(var(md5parent), llo:containsEntry, Datadoc),
      rdf(var(md5parent), llo:md5, var(parentMd5))
    ],
    [Row],
    [limit(1)]
  ),
  maplist(rdf_literal_data(value), Row, [ParentMd5,EntryPath]).



datadoc_cleaning(L):-
  lwm_sparql_select(
    [llo],
    [datadoc],
    [
      rdf(var(datadoc), llo:startClean, var(startClean)),
      not([
        rdf(var(datadoc), llo:endClean, var(endClean))
      ])
    ],
    L0,
    []
  ),
  flatten(L0, L).



%! datadoc_content_type(+Datadoc:uri, -ContentType:atom) is semidet.
% Returns a variable if the content type is not known.

datadoc_content_type(Datadoc, ContentType):-
  lwm_sparql_select(
    [llo],
    [contentType],
    [rdf(Datadoc, llo:contentType, var(contentType))],
    [[ContentTypeLiteral]],
    [limit(1)]
  ),
  rdf_literal_data(value, ContentTypeLiteral, ContentType).



%! datadoc_describe(+Datadoc:uri, -Triples:list(compound)) is det.

datadoc_describe(Datadoc, Triples):-
  lwm_sparql_select(
    [llo],
    [p,o],
    [rdf(Datadoc, var(p), var(o))],
    Rows,
    [distinct(true)]
  ),
  maplist(pair_to_triple(Datadoc), Rows, Triples).

pair_to_triple(S, [P,O], rdf(S,P,O)).



%! datadoc_exists(+Datadoc:uri) is semidet.

datadoc_exists(Datadoc):-
  lwm_sparql_ask([llo], [rdf(Datadoc,llo:md5,var(md5))], []).



%! datadoc_file_extension(+Datadoc:uri, -FileExtension:atom) is det.

datadoc_file_extension(Datadoc, FileExtension):-
  lwm_sparql_select(
    [llo],
    [fileExtension],
    [rdf(Datadoc, llo:fileExtension, var(fileExtension))],
    [[FileExtensionLiteral]],
    [limit(1)]
  ),
  rdf_literal_data(value, FileExtensionLiteral, FileExtension).



%! datadoc_has_triples(+Datadoc:uri) is semidet.

datadoc_has_triples(Datadoc):-
  lwm_sparql_ask([llo], [rdf(Datadoc,llo:triples,var(triples))], []).



%! datadoc_source(+Datadoc:uri, -Source:atom) is det.
% Returns the original source of the given datadocument.
%
% This is either a URL simpliciter,
% or a URL suffixed by an archive entry path.

% The data document derives from a URL.
datadoc_source(Datadoc, Url):-
  datadoc_location(Datadoc, Url), !.
% The data document derives from an archive entry.
datadoc_source(Datadoc, Source):-
  lwm_sparql_select(
    [llo],
    [parent,path],
    [
      rdf(Datadoc, llo:path, var(path)),
      rdf(var(parent), llo:containsEntry, Datadoc)
    ],
    [[Parent,PathLiteral]],
    [limit(1)]
  ),
  rdf_literal_data(value, PathLiteral, Path),
  datadoc_source(Parent, ParentSource),
  atomic_list_concat([ParentSource,Path], ' ', Source).



%! datadoc_location(+Datadoc:iri, -Location:uri) is det.

datadoc_location(Datadoc, Url):-
  lwm_sparql_select(
    [llo],
    [url],
    [rdf(Datadoc, llo:url, var(url))],
    [[Url]],
    [limit(1)]
  ).



%! datadoc_unpacked_size(+Datadoc:iri, -UnpackedSize:nonneg) is det.

datadoc_unpacked_size(Datadoc, UnpackedSize):-
  lwm_sparql_select(
    [llo],
    [unpackedSize],
    [rdf(Datadoc, llo:unpackedSize, var(unpackedSize))],
    [[UnpackedSizeLiteral]],
    [limit(1)]
  ),
  rdf_literal_data(value, UnpackedSizeLiteral, UnpackedSize).



%! datadoc_unpacking(-Datadocs:list(iri)) is nondet.

datadoc_unpacking(L):-
  lwm_sparql_select(
    [llo],
    [datadoc],
    [
      rdf(var(datadoc), llo:startUnpack, var(startUnpack)),
      not([
        rdf(var(datadoc), llo:endUnpack, var(endUnpack))
      ])
    ],
    L0,
    []
  ),
  flatten(L0, L).



%! datadoc_p_os(+Datadoc:iri, +Property:iri, -Objects:list(rdf_term)) is det.

datadoc_p_os(Datadoc, P, Os):-
  lwm_sparql_select(
    [llo],
    [o],
    [rdf(Datadoc,P,var(o))],
    Os0,
    []
  ),
  flatten(Os0, Os).


xquery version "1.0-ml";
(: search controller library module. :)

module namespace ss="http://developer.marklogic.com/site/search" ;

declare default function namespace "http://www.w3.org/2005/xpath-functions" ;

import module namespace search="http://marklogic.com/appservices/search"
  at "/MarkLogic/appservices/search/search.xqy" ;

import module namespace ml="http://developer.marklogic.com/site/internal"
  at "/model/data-access.xqy" ;
import module namespace srv="http://marklogic.com/rundmc/server-urls"
  at "/controller/server-urls.xqy" ;

import module namespace api="http://marklogic.com/rundmc/api"
  at "/apidoc/model/data-access.xqy";

declare variable $INPUT-NAME-API := 'api' ;

declare variable $INPUT-NAME-API-VERSION := 'v' ;

(: If applicable, translate URIs for XHTML-Tidy'd docs
 : back to the original HTML URI.
 :)
declare function ss:rewrite-html-links($uri as xs:string)
as xs:string
{
  if (not(ends-with($uri, '_html.xhtml'))) then $uri
  else replace($uri, '_html\.xhtml$', '.html')
};

declare function ss:options(
  $version as xs:string,
  $is-api as xs:boolean,
  $facets as xs:boolean,
  $query as xs:boolean,
  $results as xs:boolean)
as element(search:options)
{
  element search:options {
    element search:additional-query {
      ml:search-corpus-query($version, $is-api)
    },

    <search:constraint name="cat">
      <search:collection prefix="{ $ml:CATEGORY-PREFIX }"/>
    </search:constraint>
    ,
    <search:constraint name="param">
      <search:value>
        <search:element ns="{ $api:NAMESPACE }" name="param-type"/>
      </search:value>
    </search:constraint>
    ,
    <search:constraint name="return">
      <search:value>
        <search:element ns="{ $api:NAMESPACE }" name="return"/>
      </search:value>
    </search:constraint>
    ,

    element search:return-facets { $facets },
    element search:return-query { $query },
    element search:return-results { $results },

    element search:search-option { 'unfiltered' }
  }
};

(: Remove constraints recursively. :)
declare function ss:remove-constraints(
  $q as xs:string,
  $constraints as xs:string*,
  $options as element(search:options))
as xs:string
{
  if (empty($constraints)) then $q else
  let $new-q := search:remove-constraint($q, $constraints[1], $options)
  let $rest := subsequence($constraints, 2)
  return (
    if (empty($rest)) then $new-q
    else ss:remove-constraints($new-q, $rest, $options))
};

declare function ss:qtext-without-constraints(
  $response as element(search:response),
  $options as element(search:options))
as xs:string
{
  ss:remove-constraints(
    $response/search:qtext, $response/search:query//@qtextconst, $options)
};

(: This does some surgery on the response.
 : If the original query containts a category constraint,
 : that means the user selected a facet.
 : We want the constrained results,
 : but the facets should still be unconstrained.
 : To arrange this we search twice and merge the responses.
 : Display uses both totals.
 :)
declare function ss:search-response(
  $version as xs:string,
  $is-api as xs:boolean,
  $query as xs:string+,
  $response as element(search:response))
as element(search:response)
{
  element search:response {
    $response/@* ! (
      typeswitch(.)
      case attribute(total) return attribute facet-total { . }
      default return .),
    attribute query-unconstrained { $query },
    (: We also use the @total from the unconstrained facets,
     : as the value for "All categories".
     : So put that attribute and the facet elements before any other nodes.
     :)
    search:search(
      $query,
      ss:options(
        $version, $is-api, true(), false(), false()))/(@total|search:facet),
    $response/node()
  }
};

declare function ss:search-response(
  $version as xs:string,
  $is-api as xs:boolean,
  $query as xs:string+,
  $options as element(search:options),
  $response as element(search:response))
as element(search:response)
{
  if (xs:boolean($options/search:return-facets)) then $response
  else ss:search-response(
    $version, $is-api,
    ss:qtext-without-constraints($response, $options),
    $response)
};

declare function ss:search(
  $version as xs:string,
  $is-api as xs:boolean,
  $query as xs:string+,
  $start as xs:integer,
  $size as xs:integer,
  $options as element(search:options))
as element(search:response)
{
  ss:search-response(
    $version, $is-api, $query, $options,
    search:search($query, $options, $start, $size))
};

declare function ss:search(
  $version as xs:string,
  $is-api as xs:boolean,
  $query as xs:string+,
  $start as xs:integer,
  $size as xs:integer)
as element(search:response)
{
  ss:search(
    $version, $is-api, $query,
    $start, $size,
    ss:options(
      $version, $is-api, not(contains($query, 'cat:')), true(), true()))
};

declare function ss:param(
  $name as xs:string,
  $value as xs:string)
as xs:string
{
  concat($name, '=', encode-for-uri($value))
};

declare function ss:query-string(
  $params as xs:string*)
as xs:string
{
  if (empty($params)) then ''
  else string-join($params, '&amp;')
};

declare function ss:href(
  $version as xs:string,
  $query as xs:string,
  $is-api as xs:boolean,
  $page as xs:integer?)
as xs:string
{
  concat(
    $srv:search-page-url,
    '?',
    ss:query-string(
      (ss:param('q', $query),
        if (not($is-api)) then ()
        else ss:param($ss:INPUT-NAME-API, xs:string($is-api)),
        ss:param($ss:INPUT-NAME-API-VERSION, $version),
        ss:param('p', xs:string($page)))))
};

declare function ss:href(
  $version as xs:string,
  $query as xs:string,
  $is-api as xs:boolean)
as xs:string
{
  ss:href($version, $query, $is-api, ())
};

declare function ss:result-uri(
  $uri as xs:string,
  $highlight-query as xs:string?,
  $is-api-doc as xs:boolean,
  $api-version-prefix as xs:string)
as xs:string
{
  concat(
    if (not($is-api-doc)) then ml:external-uri-main($uri)
    else concat(
      $srv:effective-api-server,
      $api-version-prefix,
      ml:external-uri-for-string(ss:rewrite-html-links($uri))),
    (: Add the highlight param if needed.
     : The external-uri-main function never adds a query string,
     : so we have a free hand.
     :)
    if (not($highlight-query)) then ''
    else concat('?', ss:query-string(ss:param('hq', $highlight-query))))
};

declare function ss:facet-value-display($e as element())
  as xs:string
{
  typeswitch($e)
  case element(search:response) return 'All categories'
  default return (
    (: TODO move this into XML or JSON? :)
    switch($e/@name)
    case 'blog' return 'Blog posts'
    case 'code' return 'Open-source projects'
    case 'event' return 'Events'
    case 'rest-api' return 'REST API docs'

    case 'function' return 'Function pages'
    case 'function/javascript' return 'JavaScript'
    case 'function/xquery' return 'XQuery/XSLT'

    case 'help' return 'Admin help pages'

    case 'guide' return 'User guides'

    case 'guide/admin' return 'Admin'
    case 'guide/admin-api' return 'Admin API'
    case 'guide/app-builder' return 'App Builder'
    case 'guide/app-dev' return 'Application Development'
    case 'guide/cluster' return 'Clusters'
    case 'guide/concepts' return 'Concepts'
    case 'guide/copyright' return 'Copyright'
    case 'guide/cpf' return 'CPF'
    case 'guide/database-replication' return 'Database Replication'
    case 'guide/ec2' return 'EC2'
    case 'guide/flexrep' return 'Flexible Replication'
    case 'guide/getting-started' return 'Getting Started'
    case 'guide/infostudio' return 'Info Studio'
    case 'guide/ingestion' return 'Ingestion'
    case 'guide/installation' return 'Installation'
    case 'guide/java' return 'Java'
    case 'guide/jsref' return 'JavaScript'
    case 'guide/mapreduce' return 'Hadoop'
    case 'guide/messages' return 'Messages'
    case 'guide/monitoring' return 'Monitoring'
    case 'guide/node-dev' return 'Node.js'
    case 'guide/performance' return 'Performance'
    case 'guide/qconsole' return 'Query Console'
    case 'guide/ref-arch' return 'Reference Architecture'
    case 'guide/relnotes' return 'Release Notes'
    case 'guide/rest-dev' return 'REST Development'
    case 'guide/search-dev' return 'Search Development'
    case 'guide/security' return 'Security'
    case 'guide/semantics' return 'Semantics'
    case 'guide/sharepoint' return 'Sharepoint'
    case 'guide/sql' return 'SQL'
    case 'guide/temporal' return 'Temporal'
    case 'guide/xcc' return 'XCC'
    case 'guide/xquery' return 'XQuery'

    case 'news' return 'News items'
    case 'tutorial' return 'Tutorials'
    case 'xcc' return 'XCC Connector API docs'
    case 'java-api' return 'Java Client API docs'
    case 'hadoop' return 'Hadoop Connector API docs'
    case 'xccn' return 'XCC Connector .Net docs'
    case 'other' return 'Miscellaneous pages'
    case 'cpp' return 'C++ API docs'
    default return $e/@name)
};

(: Search result icon file names. TODO move into XML file? :)
declare function ss:result-img-src($name as xs:string)
as xs:string
{
  switch($name)
  case 'all' return 'i_mag_logo_small'
  case 'blog' return 'i_rss_small'
  case 'code' return 'i_opensource'
  case 'event' return 'i_calendar'
  case 'function' return 'i_function'
  (: TODO give help a different icon :)
  case 'help' return 'i_folder'
  case 'rest-api' return 'i_rest'
  case 'guide' return 'i_documentation'
  case 'news' return 'i_newspaper'
  case 'tutorial' return 'i_monitor'
  case 'xcc' return 'i_java'
  case 'java-api' return 'i_java'
  case 'hadoop' return 'i_java'
  case 'xccn' return 'i_dotnet'
  case 'other' return 'i_folder'
  (: TODO give cpp a different icon :)
  case 'cpp' return 'i_folder'
default return TODO
};

(: Search result icon file widths. TODO move into XML file? :)
declare function ss:result-img-width($name as xs:string)
  as xs:int
{
  switch($name)
  case 'guide' return 29
  case 'rest-api' return 28
  (: All other icons are 30px wide. :)
  default return 30
};

(: Search result icon file heights. TODO move into XML file? :)
declare function ss:result-img-height($name as xs:string)
  as xs:int
{
  switch($name)
  case 'all' return 23
  case 'blog' return 23
  case 'code' return 24
  case 'event' return 24
  case 'function' return 27
  case 'help' return 19
  case 'rest-api' return 28
  case 'guide' return 25
  case 'news' return 23
  case 'tutorial' return 21
  case 'xcc' return 26
  case 'java-api' return 26
  case 'hadoop' return 26
  case 'xccn' return 24
  case 'other' return 19
  default return 30
};

(: search.xqm :)
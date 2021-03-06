##
# MIT License
#
# Copyright (c) 2016 Elias Saalmann, Christian Frommert, Simon Jakobi,
# Arne Jonas Präger, Maxi Bornmann, Georg Hackel, Eric Füg
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

module Jekyll
  module JekyllRdf
    ##
    # Internal module to hold the medthod #sparql_query
    #
    module Filter

      ##
      # Executes a SPARQL query. The supplied query is augmented by replacing each occurence of '?resourceUri' by the URI of the context RDF resource.
      # Returns an Array of bindings. Each binding is a Hash mapping variables to their values.
      #
      # * +input+ - the context RDF resource
      # * +query+ - the SPARQL query
      #
      def sparql_query(resource = nil, query)
        if(rdf_substitude_nil?(resource))
          query.gsub!('?resourceUri', "<#{Jekyll::JekyllRdf::Helper::RdfHelper::page.data['rdf'].term}>")
        elsif(resource.class <= Array)
          resource.each_with_index do |uri, index|
            return unless valid_resource?(uri)
            if(uri.class <= Jekyll::JekyllRdf::Drops::RdfResource)
              query.gsub!("?resourceUri_#{index}", uri.term.to_ntriples)
            else
              query.gsub!("?resourceUri_#{index}", "#{rdf_resolve_prefix(uri.to_s)}")
            end
          end
        else
          return unless valid_resource?(resource)
          query.gsub!('?resourceUri', to_string_wrap(resource))
        end if query.include? '?resourceUri'  #the only purpose of the if statement is to substitute ?resourceUri
        if(!Jekyll::JekyllRdf::Helper::RdfHelper::page.data["rdf_prefixes"].nil?)
          query = query.prepend(" ").prepend(Jekyll::JekyllRdf::Helper::RdfHelper::page.data["rdf_prefixes"])
        end
        begin
          result = Jekyll::JekyllRdf::Helper::RdfHelper::sparql.query(query).map do |solution|
            hsh = solution.to_h
            hsh.update(hsh){ |k,v| Jekyll::JekyllRdf::Drops::RdfTerm.build_term_drop(v, Jekyll::JekyllRdf::Helper::RdfHelper::site, true).add_necessities(Jekyll::JekyllRdf::Helper::RdfHelper::site, Jekyll::JekyllRdf::Helper::RdfHelper::page)}
            hsh.collect{|k,v| [k.to_s, v]}.to_h
          end
          return result
        rescue SPARQL::Client::ClientError => ce
          Jekyll.logger.error("client error experienced: \n #{query} \n Error Message: #{ce.message}")
        rescue SPARQL::MalformedQuery => mq
          Jekyll.logger.error("malformed query found: \n #{query} \n Error Message: #{mq.message}")
        rescue Exception => e
          Jekyll.logger.error("unknown Exception of class: #{e.class} in sparql_query \n Query: #{query} \nMessage: #{e.message} \nTrace #{e.backtrace.drop(1).map{|s| "\t#{s}"}.join("\n")}")
        end
        return []
      end

    end
  end
end

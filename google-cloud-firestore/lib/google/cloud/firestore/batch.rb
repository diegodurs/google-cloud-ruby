# Copyright 2017, Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "google/cloud/firestore/document"
require "google/cloud/firestore/collection"
require "google/cloud/firestore/query"
require "google/cloud/firestore/convert"

module Google
  module Cloud
    module Firestore
      ##
      # # Batch
      #
      # A batch in Cloud Firestore is a set of writes that execute
      # atomically at a single logical point in time in a database.
      #
      # All changes are accumulated in memory until the block passed to
      # {Database#batch} completes. Unlike transactions, batches are not
      # automatically retried. See {Database#batch}.
      #
      # @example
      #   require "google/cloud/firestore"
      #
      #   firestore = Google::Cloud::Firestore.new
      #
      #   firestore.batch do |b|
      #     # Set the data for NYC
      #     b.col("cities").doc("NYC").set({ name: "New York City" })
      #
      #     # Update the population for SF
      #     b.col("cities").doc("SF").update({ population: 1000000 })
      #
      #     # Delete LA
      #     b.col("cities").doc("LA").delete
      #   end
      #
      class Batch
        ##
        # New Batch object.
        def initialize
          @writes = []
        end

        ##
        # The project resource the Cloud Firestore batch belongs to.
        #
        # @return [Project] project resource
        def project
          @database.project
        end

        ##
        # The database resource the Cloud Firestore batch belongs to.
        #
        # @return [Database] database resource.
        def database
          @database
        end

        ##
        # The project identifier for the Cloud Firestore database.
        #
        # @return [String] project identifier.
        def project_id
          @database.project_id
        end

        ##
        # The database identifier for the Cloud Firestore batch.
        #
        # @return [String] database identifier.
        def database_id
          @database.database_id
        end

        ##
        # The full Database path for the Cloud Firestore batch.
        #
        # @return [String] database resource path.
        def path
          @database.path
        end

        ##
        # Retrieves a list of collections.
        #
        # @yield [collections] The block for accessing the collections.
        # @yieldparam [Collection::Reference] collection A collection.
        #
        # @return [Enumerator<Collection::Reference>] collection list.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get the root collections
        #     b.cols.each do |col|
        #       # Print the collection
        #       puts col.collection_id
        #     end
        #   end
        #
        def cols
          ensure_service!

          return enum_for(:cols) unless block_given?

          collection_ids = service.list_collections "#{path}/documents"
          collection_ids.each { |collection_id| yield col(collection_id) }
        end
        alias_method :collections, :cols

        ##
        # Retrieves a collection.
        #
        # @param [String] collection_path A string representing the path of the
        #   collection, relative to the document root of the database.
        #
        # @return [Collection::Reference] A collection.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get the cities collection
        #     cities_col = b.col "cities"
        #
        #     # Get the document for NYC
        #     nyc_ref = cities_col.doc "NYC"
        #
        #     # Set the name for NYC
        #     b.set(nyc_ref, { name: "New York City" })
        #   end
        #
        def col collection_path
          if collection_path.to_s.split("/").count.even?
            fail ArgumentError, "collection_path must refer to a collection."
          end

          Collection.from_path "#{path}/documents/#{collection_path}", self
        end
        alias_method :collection, :col

        ##
        # Retrieves a list of documents.
        #
        # @param [String] collection_path A string representing the path of the
        #   collection, relative to the document root of the database.
        #
        # @yield [documents] The block for accessing the documents.
        # @yieldparam [Document::Reference] document A document.
        #
        # @return [Enumerator<Document::Reference>] documents list.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get and print all city documents
        #     b.docs("cities").each do |city|
        #       puts city.document_id
        #     end
        #   end
        #
        def docs collection_path, &block
          col(collection_path).docs(&block)
        end
        alias_method :documents, :docs

        ##
        # Retrieves a document.
        #
        # @param [String] document_path A string representing the path of the
        #   document, relative to the document root of the database.
        #
        # @return [Document::Reference] A document.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get a document
        #     nyc_ref = b.doc "cities/NYC"
        #
        #     # Print the document ID
        #     puts nyc_ref.document_id
        #   end
        #
        def doc document_path
          if document_path.to_s.split("/").count.odd?
            fail ArgumentError, "document_path must refer to a document."
          end

          doc_path = "#{path}/documents/#{document_path}"

          Document.from_path doc_path, self
        end
        alias_method :document, :doc

        ##
        # Retrieves a list of documents with data.
        #
        # @param [String, Document::Reference] docs One or more strings
        #   representing the path of the document, or document reference
        #   objects.
        # @param [Array<String|Symbol>, String|Symbol] mask A list of field
        #   paths to filter the returned document data by.
        #
        # @yield [documents] The block for accessing the documents with data.
        # @yieldparam [Document::Snapshot] document A document with data.
        #
        # @return [Enumerator<Document::Snapshot>] documents with data list.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get and print city documents
        #     b.get_all("cities/NYC", "cities/SF", "cities/LA").each do |city|
        #       puts city.document_id
        #     end
        #   end
        #
        def get_all *docs, mask: nil
          ensure_service!

          return enum_for(:get_all, docs, mask: mask) unless block_given?

          doc_paths = Array(docs).flatten.map do |doc_path|
            coalesce_doc_path_argument doc_path
          end

          results = service.get_documents doc_paths, mask: mask
          results.each do |result|
            next if result.result.nil?
            yield Document.from_batch_result(result, self)
          end
        end
        alias_method :get_docs, :get_all
        alias_method :get_documents, :get_all
        alias_method :find, :get_all

        ##
        # Creates a query object.
        #
        # @return [Query] A query.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.query.select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def query
          Query.start "#{path}/documents", self
        end
        alias_method :q, :query

        ##
        # Creates a query object with method `select` called on it. (See
        # {Query#select}.)
        #
        # @param [String, Symbol] fields A field mask to filter results with and
        #   return only the specified fields. One or more field paths can be
        #   specified.
        #
        # @return [Query] A query with `select` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def select *fields
          query.select fields
        end

        ##
        # Creates a query object with method `from` called on it. (See
        # {Query#from}.)
        #
        # @param [String] collection_path A string representing the path of the
        #   collection, relative to the document root of the database, to query
        #   results from.
        #
        # @return [Query] A query with `from` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.from(:cities).select(:population)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def from collection_path
          query.from collection_path
        end

        ##
        # Creates a query object with method `where` called on it. (See
        # {Query#where}.)
        #
        # @param [String, Symbol] field A field mask to filter results with and
        #   return only the specified fields. One or more field paths can be
        #   specified.
        # @param [String, Symbol] operator The operation to compare the field
        #   to. Acceptable values include:
        #
        #   * less than: `<`, `lt`
        #   * less than or equal: `<=`, `lte`
        #   * greater than: `>`, `gt`
        #   * greater than or equal: `>=`, `gte`
        #   * equal: `=`, `==`, `eq`, `eql`, `is`
        # @param [Object] value A value the field is compared to.
        #
        # @return [Query] A query with `where` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.where(:population, :>=, 1000000).
        #               select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def where field, operator, value
          query.where field, operator, value
        end

        ##
        # Creates a query object with method `order` called on it. (See
        # {Query#order}.)
        #
        # @param [String, Symbol] field A field mask to order results with.
        # @param [String, Symbol] direction The direction to order the results
        #   by. Optional. Default is ascending.
        #
        # @return [Query] A query with `order` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.order(:name).select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def order field, direction = :asc
          query.order field, direction
        end

        ##
        # Creates a query object with method `offset` called on it. (See
        # {Query#offset}.)
        #
        # @param [Integer] num The number of results to skip.
        #
        # @return [Query] A query with `offset` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.offset(10).limit(5).
        #               select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def offset num
          query.offset num
        end

        ##
        # Creates a query object with method `limit` called on it. (See
        # {Query#limit}.)
        #
        # @param [Integer] num The maximum number of results to return.
        #
        # @return [Query] A query with `limit` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.limit(5).offset(10).
        #               select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def limit num
          query.limit num
        end

        ##
        # Creates a query object with method `start_at` called on it. (See
        # {Query#start_at}.)
        #
        # @param [Object] values The field value to start the query at.
        #
        # @return [Query] A query with `start_at` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.start_at("NYC").select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def start_at *values
          query.start_at values
        end

        ##
        # Creates a query object with method `start_after` called on it. (See
        # {Query#start_after}.)
        #
        # @param [Object] values The field value to start the query after.
        #
        # @return [Query] A query with `start_after` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.start_after("NYC").select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def start_after *values
          query.start_after values
        end

        ##
        # Creates a query object with method `end_before` called on it. (See
        # {Query#end_before}.)
        #
        # @param [Object] values The field value to end the query before.
        #
        # @return [Query] A query with `end_before` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.end_before("NYC").select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def end_before *values
          query.end_before values
        end

        ##
        # Creates a query object with method `end_at` called on it. (See
        # {Query#end_at}.)
        #
        # @param [Object] values The field value to end the query at.
        #
        # @return [Query] A query with `end_at` called on it.
        #
        # @example
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.end_at("NYC").select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def end_at *values
          query.end_at values
        end

        ##
        # Retrieves documents with data for the given value. Valid values can be
        # a string representing either a document or a collection of documents,
        # a document refernce object, a collection reference object, or a query
        # to be run.
        #
        # @param [String, Document::Reference, Collection::Reference, query] obj
        #   A string representing the path of a document or collection, a
        #   document reference object, a collection reference object, or a query
        #   to run.
        #
        # @yield [documents] The block for accessing the documents with data.
        # @yieldparam [Document::Reference] document A document with data.
        #
        # @return [Document::Reference, Enumerator<Document::Reference>] A
        #   single document with data when passed a document path a document
        #   refernce, or a list of documents with data when passed other valid
        #   values.
        #
        # @example Get a document with data given a document path:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get a document with data
        #     nyc_snap = b.get "cities/NYC"
        #   end
        #
        # @example Get a document with data given a document reference:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get a document reference
        #     nyc_ref = b.doc "cities/NYC"
        #
        #     # Get a document with data
        #     nyc_snap = b.get nyc_ref
        #   end
        #
        # @example Get documents with data given a collection path:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get documents for a collection path
        #     b.get("cities").each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        # @example Get documents with data given a collection reference:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get a collection reference
        #     cities_col = b.col :cities
        #
        #     # Get documents for a collection
        #     b.get(cities_col).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        # @example Get documents with data given a query:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a query
        #     query = b.select(:population).from(:cities)
        #
        #     # Get/run a query
        #     b.get(query).each do |city|
        #       puts "#{city.document_id} has #{city[:population]} residents."
        #     end
        #   end
        #
        def get obj
          ensure_not_closed!
          ensure_service!

          obj = coalesce_get_argument obj

          if obj.is_a?(Document::Reference)
            doc = get_all([obj]).first
            yield doc if block_given?
            return doc
          end

          return enum_for(:get, obj) unless block_given?

          results = service.run_query obj.parent_path, obj.grpc
          results.each do |result|
            next if result.document.nil?
            yield Document.from_query_result(result, self)
          end
        end
        alias_method :run, :get

        ##
        # Create a document with the provided object values.
        #
        # The batch will fail if the document already exists.
        #
        # @param [String, Document::Reference] doc A string representing the
        #   path of the document, or a document reference object.
        # @param [Hash] data The document's fields and values.
        #
        # @example Create a document using a document path:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a document
        #     b.create("cities/NYC", { name: "New York City" })
        #   end
        #
        # @example Create a document using a document reference:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get a document reference
        #     nyc_ref = b.doc "cities/NYC"
        #
        #     # Create a document
        #     b.create(nyc_ref, { name: "New York City" })
        #   end
        #
        def create doc, data
          ensure_not_closed!

          doc_path = coalesce_doc_path_argument doc

          Convert.create_writes(doc_path, data).each do |write|
            @writes << write
          end

          nil
        end

        ##
        # Write to document with the provided object values. If the document
        # does not exist, it will be created. By default, the provided data
        # overwrites existing data, but the provided data can be merged into the
        # existing document using the `merge` argument.
        #
        # @param [String, Document::Reference] doc A string representing the
        #   path of the document, or a document reference object.
        # @param [Hash] data The document's fields and values.
        # @param [true, String|Symbol, Array<String|Symbol>] merge When provided
        #   and `true` all data is merged with the existing docuemnt data.  When
        #   provided only the specified as a list of field paths are merged with
        #   the existing docuemnt data. The default is to overwrite the existing
        #   docuemnt data.
        #
        # @example Set a document using a document path:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a document
        #     b.set("cities/NYC", { name: "New York City" })
        #   end
        #
        # @example Create a document using a document reference:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get a document reference
        #     nyc_ref = b.doc "cities/NYC"
        #
        #     # Create a document
        #     b.set(nyc_ref, { name: "New York City" })
        #   end
        #
        # @example Set a document and merge all data:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a document
        #     b.set("cities/NYC", { name: "New York City" }, merge: true)
        #   end
        #
        # @example Set a document and merge only name:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a document
        #     b.set("cities/NYC", { name: "New York City" }, merge: [:name])
        #   end
        #
        def set doc, data, merge: nil
          ensure_not_closed!

          doc_path = coalesce_doc_path_argument doc

          Convert.set_writes(doc_path, data, merge: merge).each do |write|
            @writes << write
          end

          nil
        end

        ##
        # Write to document with the provided object values. If the document
        # does not exist, it will be created. By default, the provided data
        # overwrites existing data, but the provided data can be merged into the
        # existing document using the `merge` argument.
        #
        # The batch will fail if the document does not exist.
        #
        # @param [String, Document::Reference] doc A string representing the
        #   path of the document, or a document reference object.
        # @param [Hash] data The document's fields and values.
        # @param [Time] update_time When set, the document must have been last
        #   updated at that time. Optional.
        #
        # @example Update a document using a document path:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Create a document
        #     b.update("cities/NYC", { name: "New York City" })
        #   end
        #
        # @example Update a document using a document reference:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Get a document reference
        #     nyc_ref = b.doc "cities/NYC"
        #
        #     # Create a document
        #     b.update(nyc_ref, { name: "New York City" })
        #   end
        #
        # @example Update a document using `update_time`:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   last_updated_at = Time.now - 42 # 42 seconds ago
        #
        #   firestore.batch do |b|
        #     # Create a document
        #     b.update("cities/NYC", { name: "New York City" },
        #              update_time: last_updated_at)
        #   end
        #
        def update doc, data, update_time: nil
          ensure_not_closed!

          doc_path = coalesce_doc_path_argument doc

          Convert.update_writes(doc_path, data,
                                update_time: update_time).each do |write|
            @writes << write
          end

          nil
        end

        ##
        # Deletes a document from the database.
        #
        # @param [String, Document::Reference] doc A string representing the
        #   path of the document, or a document reference object.
        # @param [Boolean] exists Whether the document must exist. When `true,
        #   the document must exist or an error is raised. Default is `false`.
        #   Optional.
        # @param [Time] update_time When set, the document must have been last
        #   updated at that time. Optional.
        #
        # @example Delete a document using a document path:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Delete a document
        #     b.delete "cities/NYC"
        #   end
        #
        # @example Delete a document using a document reference:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #
        #   firestore.batch do |b|
        #     # Get a document reference
        #     nyc_ref = firestore.doc "cities/NYC"
        #
        #     # Delete a document
        #     b.delete nyc_ref
        #   end
        #
        # @example Delete a document using `exists`:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   firestore.batch do |b|
        #     # Delete a document
        #     b.delete "cities/NYC", exists: true
        #   end
        #
        # @example Delete a document using `update_time`:
        #   require "google/cloud/firestore"
        #
        #   firestore = Google::Cloud::Firestore.new
        #
        #   last_updated_at = Time.now - 42 # 42 seconds ago
        #
        #   firestore.batch do |b|
        #     # Delete a document
        #     b.delete "cities/NYC", update_time: last_updated_at
        #   end
        #
        def delete doc, exists: nil, update_time: nil
          ensure_not_closed!

          doc_path = coalesce_doc_path_argument doc

          @writes << Convert.delete_write(doc_path, exists: exists,
                                                    update_time: update_time)

          nil
        end

        ##
        # @private commit the batch
        def commit
          ensure_not_closed!
          @closed = true
          return nil if @writes.empty?
          resp = service.commit @writes
          Convert.timestamp_to_time resp.commit_time
        end

        ##
        # @private the batch is complete and closed
        def closed?
          @closed
        end

        ##
        # @private New Batch reference object from a path.
        def self.from_database database
          new.tap do |b|
            b.instance_variable_set :@database, database
          end
        end

        ##
        # @private The database's Service object.
        def service
          ensure_database!

          database.service
        end

        protected

        ##
        # @private
        def coalesce_get_argument obj
          if obj.is_a?(String) || obj.is_a?(Symbol)
            if obj.to_s.split("/").count.even?
              return doc obj # Convert a Document::Reference
            else
              return col(obj).query # Convert to Query
            end
          end

          return obj.ref if obj.is_a?(Document::Snapshot)

          return obj.query if obj.is_a? Collection::Reference

          obj
        end

        ##
        # @private
        def coalesce_doc_path_argument doc_path
          return doc_path.path if doc_path.respond_to? :path

          doc(doc_path).path
        end

        ##
        # @private
        def ensure_not_closed!
          fail "batch is closed" if closed?
        end

        ##
        # @private Raise an error unless an database available.
        def ensure_database!
          fail "Must have active connection to service" unless database
        end

        ##
        # @private Raise an error unless an active connection to the service
        # is available.
        def ensure_service!
          fail "Must have active connection to service" unless service
        end
      end
    end
  end
end

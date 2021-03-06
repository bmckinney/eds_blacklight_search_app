# -*- encoding : utf-8 -*-
require 'ebsco/eds'

class CatalogController < ApplicationController

  include Blacklight::Eds::Catalog

  before_action :eds_init
  def eds_init
    guest = current_or_guest_user.guest
    if session.key?('guest')
      # user login/logon, update guest status in session
      if session['guest'] != guest
        session['guest'] = guest
        session['eds_session_token'] =
          EBSCO::EDS::Session.new(guest: guest,
                                  caller: 'status-changed').session_token
      end
    else
      # new user session, set guest and session token
      session['guest'] = guest
      session['eds_session_token'] =
        EBSCO::EDS::Session.new(guest: guest, caller: 'new-session').session_token
    end
    puts 'session token: ' + session['eds_session_token'].inspect
    puts 'session guest: ' + session['guest'].inspect
  end

  configure_blacklight do |config|

    config.default_solr_params = { rows: 10 }

    # solr field configuration for search results/index views
    config.index.title_field = :title_display
    config.index.show_link = 'title_display'
    config.index.record_display_type = 'format'
    config.index.thumbnail_field = 'cover_medium_url'

    #config.add_index_field 'title_display', label: 'Title', :highlight => true
    config.add_index_field 'author_display', label: 'Author'
    config.add_index_field 'format', label: 'Format'
    config.add_index_field 'academic_journal', label: 'Journal'
    config.add_index_field 'language_facet', label: 'Language'
    config.add_index_field 'pub_date', label: 'Year'
    config.add_index_field 'pub_info', label: 'Published'
    config.add_index_field 'fulltext_link', label: 'Fulltext', helper_method: :best_fulltext
    config.add_index_field 'id'

    # solr field configuration for document/show views
    config.show.html_title = 'title_display'
    config.show.heading = 'title_display'
    config.show.display_type = 'format'
    config.show.pub_date = 'pub_date'
    config.show.pub_info = 'pub_info'
    config.show.abstract = 'abstract'
    config.show.full_text_url = 'full_text_url'
    config.show.plink = 'plink'

    config.add_facet_field 'search_limiters', label: 'Search Limiters'
    config.add_facet_field 'format', label: 'Format'
    config.add_facet_field 'library_location_facet', label: 'Library Location', limit: true
    config.add_facet_field 'pub_date_facet', label: 'Publication Year', single: true
    config.add_facet_field 'category_facet', label: 'Category', limit: 20
    config.add_facet_field 'subject_topic_facet', label: 'Topic', limit: 20
    config.add_facet_field 'language_facet', label: 'Language', limit: true
    config.add_facet_field 'journal_facet', label: 'Journals', limit: true
    config.add_facet_field 'geographic_facet', label: 'Geography', limit: true
    config.add_facet_field 'publisher_facet', label: 'Publisher', limit: true
    config.add_facet_field 'content_provider_facet', label: 'Content Provider', limit: true

    # solr fields to be displayed in the show (single result) view
    #   The ordering of the field names is the order of the display
    config.add_show_field 'title_display', label: 'Title'
    config.add_show_field 'academic_journal', label: 'Journal'
    config.add_show_field 'author_display', label: 'Author'
    config.add_show_field 'format', label: 'Format'
    config.add_show_field 'pub_date', label: 'Publication Date'
    config.add_show_field 'pub_info', label: 'Published'
    config.add_show_field 'abstract', label: 'Abstract'
    config.add_show_field 'doi', label: 'DOI', helper_method: :doi_link
    # config.add_show_field 'links', helper_method: :eds_links, label: 'Links'
    config.add_show_field 'fulltext_link', label: 'Fulltext', helper_method: :best_fulltext
    config.add_show_field 'html_fulltext', label: 'Full Text', helper_method: :html_fulltext

    config.add_search_field 'all_fields', label: 'All Fields'

    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.

    config.add_search_field('title') do |field|
      # solr_parameters hash are sent to Solr as ordinary url query params.
      field.solr_parameters = { :'spellcheck.dictionary' => 'title' }

      # :solr_local_parameters will be sent using Solr LocalParams
      # syntax, as eg {! qf=$title_qf }. This is neccesary to use
      # Solr parameter de-referencing like $title_qf.
      # See: http://wiki.apache.org/solr/LocalParams
      field.solr_local_parameters = {
          qf: '$title_qf',
          pf: '$title_pf'
      }
    end

    config.add_search_field('author') do |field|
      field.solr_parameters = { :'spellcheck.dictionary' => 'author' }
      field.solr_local_parameters = {
          qf: '$author_qf',
          pf: '$author_pf'
      }
    end

    # Specifying a :qt only to show it's possible, and so our internal automated
    # tests can test it. In this case it's the same as
    # config[:default_solr_parameters][:qt], so isn't actually neccesary.
    config.add_search_field('subject') do |field|
      field.solr_parameters = { :'spellcheck.dictionary' => 'subject' }
      field.qt = 'search'
      field.solr_local_parameters = {
          qf: '$subject_qf',
          pf: '$subject_pf'
      }
    end

    # Class for sending and receiving requests from a search index
    config.repository_class = Blacklight::Eds::Repository

    config.add_sort_field 'score desc', :label => 'most relevant'
    config.add_sort_field 'pub_date_sort desc', :label => 'most recent'
    #config.add_sort_field 'pub_date_sort asc', :label => 'oldest'

    # force spell checking in all cases, no max results required
    config.spell_max = 9999999999

  end
end
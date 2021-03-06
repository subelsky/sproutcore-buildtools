require 'erubis'
require 'sproutcore/helpers'
require 'sproutcore/view_helpers'

module SproutCore

  module BuildTools

    # Whenever you build an HTML file for a SproutCore client, an instance of
    # this class is created to actually process and build the HTML using
    # Erubus or Haml.  If you want to add more methods to use in your HTML files, just
    # include them in HtmlContext.
    #
    class HtmlContext

      include SproutCore::Helpers::TagHelper
      include SproutCore::Helpers::TextHelper
      include SproutCore::Helpers::CaptureHelper
      include SproutCore::Helpers::StaticHelper
      include SproutCore::ViewHelpers

      attr_reader :entry, :bundle, :entries, :filename, :language, :library

      def initialize(entry, bundle, deep=true)
        @entry = nil
        @language = entry.language
        @bundle = bundle
        @library = bundle.library

        # Find all of the entries that need to be included.  If deep is true,
        # the include required bundles.  Example composite entries to include
        # their members.
        if deep
          @entries = bundle.all_required_bundles.map do |cur_bundle|
            ret = (cur_bundle == bundle) ? [entry] : cur_bundle.entries_for(:html, :language => language, :hidden => :include)
            ret.map do |e|
              e.composite? ? e.composite : [e]
            end
          end
          @entries = @entries.flatten.compact.uniq
        else
          @entries = entry.composite? ? entry.composite : [entry]
        end

        # Clean out any composites we might have collected.  They have already
        # been expanded.  Also clean out any non-localized rhtml files.
        @entries.reject! { |entry| entry.composite? || (entry.type == :html && !entry.localized?) }

        # Load any helpers before we continue
        bundle.all_required_bundles.each do |cur_bundle|
          require_helpers(nil, cur_bundle)
        end

      end

      # Actually builds the HTML file from the entry (actually from any
      # composite entries)
      def build

        @layout_path = bundle.layout_path

        # Render each filename.  By default, the output goes to the resources
        # string
        @content_for_resources = ''
        entries.each { |fn| _render_one(fn) }

        # Finally, render the layout.  This should produce the final output to
        # return
        input = File.read(@layout_path)
        
        # render using either erb or haml
        case File.extname(@layout_path)
        when /\.rhtml$/, /\.html.erb$/
          return eval(Erubis::Eruby.new.convert(input))
        when /\.haml$/, /\.html.haml$/
          require 'haml'
          return Haml::Engine.new(input).to_html(self)
        end
      end

      # render a single entry
      def _render_one(entry)
        @entry = entry
        @filename = @entry.filename

        # avoid double render of layout path
         return if @entry.source_path == @layout_path

        # render. Result goes into @content_for_resources
        input = File.read(@entry.source_path)
        
        # render using either erb or haml
        case File.extname(@entry.source_path)
        when /\.rhtml$/, /\.html.erb$/
          @content_for_resources += eval(Erubis::Eruby.new.convert(input))
        when /\.haml$/, /\.html.haml$/
          require 'haml'
          @content_for_resources += Haml::Engine.new(input).to_html(self)
        end

        @filename =nil
        @entry = nil
      end


      # Returns the current bundle name.  Often useful for generating titles,
      # etc.
      def bundle_name; bundle.bundle_name; end

      #### For Rails Compatibility.  render() does not do anything useful
      # since the new build system is nice about putting things into the right
      # place for output.
      def render; ''; end

    end

    # Builds an html file for the specified entry.  If deep is true, then this
    # will also find all of the html entries for any required bundles and
    # include them in the built html file.
    def self.build_html(entry, bundle, deep=true)
      context = HtmlContext.new(entry, bundle, deep)
      output = context.build

      FileUtils.mkdir_p(File.dirname(entry.build_path))
      f = File.open(entry.build_path, 'w')
      f.write(output)
      f.close

    end

    # Building a test is just like building a single page except that we do not include
    # all the other html templates in the project
    def self.build_test(entry, bundle); build_html(entry, bundle, false); end

  end
end

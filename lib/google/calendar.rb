module Google

  #
  # Calendar is the main object you use to interact with events.
  # use it to find, create, update and delete them.
  #
  class Calendar

    attr_reader :id, :connection, :summary

    #
    # Setup and connect to the specified Google Calendar.
    #  the +params+ paramater accepts
    # * :client_id => the client ID that you received from Google after registering your application with them (https://console.developers.google.com/). REQUIRED
    # * :client_secret => the client secret you received from Google after registering your application with them. REQUIRED
    # * :redirect_url => the url where your users will be redirected to after they have successfully permitted access to their calendars. Use 'urn:ietf:wg:oauth:2.0:oob' if you are using an 'application'" REQUIRED
    # * :calendar_id => the id of the calendar you would like to work with (see Readme.rdoc for instructions on how to find yours)
    # * :refresh_token => if a user has already given you access to their calendars, you can specify their refresh token here and you will be 'logged on' automatically (i.e. they don't need to authorize access again). OPTIONAL
    #
    # See Readme.rdoc or readme_code.rb for an explication on the OAuth2 authorization process.
    #
    # ==== Example
    # Google::Calendar.new(:client_id => YOUR_CLIENT_ID,
    #                      :client_secret => YOUR_SECRET,
    #                      :calendar => YOUR_CALENDAR_ID,
    #                      :redirect_url => "urn:ietf:wg:oauth:2.0:oob" # this is what Google uses for 'applications'
    #                     )
    #
    def initialize(params={}, connection=nil)
      @connection = connection || Connection.new(
        :client_id => params[:client_id],
        :client_secret => params[:client_secret],
        :refresh_token => params[:refresh_token],
        :redirect_url => params[:redirect_url],
        :state => params[:state]
      )

      @id = params[:calendar]
      # raise CalendarIDMissing unless @id
    end

    #
    # Setup, connect and create a Google Calendar.
    #  the +params+ paramater accepts
    # * :client_id => the client ID that you received from Google after registering your application with them (https://console.developers.google.com/). REQUIRED
    # * :client_secret => the client secret you received from Google after registering your application with them. REQUIRED
    # * :redirect_url => the url where your users will be redirected to after they have successfully permitted access to their calendars. Use 'urn:ietf:wg:oauth:2.0:oob' if you are using an 'application'" REQUIRED
    # * :summary => title of the calendar being created.
    # * :refresh_token => if a user has already given you access to their calendars, you can specify their refresh token here and you will be 'logged on' automatically (i.e. they don't need to authorize access again). OPTIONAL
    #
    # See Readme.rdoc or readme_code.rb for an explication on the OAuth2 authorization process.
    #
    # ==== Example
    # Google::Calendar.create(
    #                         :client_id => YOUR_CLIENT_ID,
    #                         :client_secret => YOUR_SECRET,
    #                         :summary => 'Test Calendar',
    #                         :redirect_url => "urn:ietf:wg:oauth:2.0:oob" # this is what Google uses for 'applications'
    #                        )
    #
    def self.create(params={}, connection=nil)
      cal = new(params, connection)
      cal.instance_variable_set(:@summary, params[:summary])

      cal.save
    end

    #
    # The URL you need to send a user in order to let them grant you access to their calendars.
    #
    def authorize_url
      @connection.authorize_url
    end

    #
    # The single use auth code that google uses during the auth process.
    #
    def auth_code
      @connection.auth_code
    end

    #
    # The current access token.  Used during a session, typically expires in a hour.
    #
    def access_token
      @connection.access_token
    end

    #
    # The refresh token is used to obtain a new access token.  It remains valid until a user revokes access.
    #
    def refresh_token
      @connection.refresh_token
    end

    #
    # Convenience method used to streamline the process of logging in with a auth code.
    #
    def login_with_auth_code(auth_code)
      @connection.login_with_auth_code(auth_code)
    end

    #
    # Convenience method used to streamline the process of logging in with a refresh token.
    #
    def login_with_refresh_token(refresh_token)
      @connection.login_with_refresh_token(refresh_token)
    end

    #
    # Save a new calender.
    #  Returns:
    #   the calendar that was saved.
    #
    def save
      response = send_calendar_request("/", :post, {:summary => @summary}.to_json)
      update_after_save(response)
    end

    #
    # Find all of the events associated with this calendar.
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def events
      event_lookup()
    end

    #
    # This is equivalent to running a search in the Google calendar web application.
    # Google does not provide a way to specify what attributes you would like to
    # search (i.e. title), by default it searches everything.
    # If you would like to find specific attribute value (i.e. title=Picnic), run a query
    # and parse the results.
    #
    # Note that it is not possible to query the extended properties using queries.
    # If you need to do so, use the alternate methods find_events_by_extended_property
    # and find_events_by_extended_property_in_range
    #
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_events(query)
      event_lookup("?q=#{query}")
    end

    #
    # Find all of the events associated with this calendar that start in the given time frame.
    # The lower bound is inclusive, whereas the upper bound is exclusive.
    # Events that overlap the range are included.
    #
    # the +options+ parameter accepts
    # :max_results => the maximum number of results to return defaults to 25 the largest number Google accepts is 2500
    # :order_by => how you would like the results ordered, can be either 'startTime' or 'updated'. Defaults to 'startTime'. Note: it must be 'updated' if expand_recurring_events is set to false.
    # :expand_recurring_events => When set to true each instance of a recurring event is returned. Defaults to true.
    #
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_events_in_range(start_min, start_max, options = {})
      formatted_start_min = encode_time(start_min)
      formatted_start_max = encode_time(start_max)
      query = "?timeMin=#{formatted_start_min}&timeMax=#{formatted_start_max}#{parse_options(options)}"
      event_lookup(query)
    end

    #
    # Find all events that are occurring at the time the method is run or later.
    #
    # the +options+ parameter accepts
    # :max_results => the maximum number of results to return defaults to 25 the largest number Google accepts is 2500
    # :order_by => how you would like the results ordered, can be either 'startTime' or 'updated'. Defaults to 'startTime'. Note: it must be 'updated' if expand_recurring_events is set to false.
    # :expand_recurring_events => When set to true each instance of a recurring event is returned. Defaults to true.
    #
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_future_events(options={})
      formatted_start_min = encode_time(Time.now)
      query = "?timeMin=#{formatted_start_min}#{parse_options(options)}"
      event_lookup(query)
    end

    #
    # Find all events that match at least one of the specified extended properties.
    #
    # the +extended_properties+ parameter is set up the same way that it is configured when creating an event
    # for example, providing the following hash { 'shared' => {'p1' => 'v1', 'p2' => v2} } will return the list of events
    # that contain either v1 for shared extended property p1 or v2 for p2.
    #
    # the +options+ parameter accepts
    # :max_results => the maximum number of results to return defaults to 25 the largest number Google accepts is 2500
    # :order_by => how you would like the results ordered, can be either 'startTime' or 'updated'. Defaults to 'startTime'. Note: it must be 'updated' if expand_recurring_events is set to false.
    # :expand_recurring_events => When set to true each instance of a recurring event is returned. Defaults to true.
    #
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_events_by_extended_properties(extended_properties, options = {})
      query_parts = []
      ['shared', 'private'].each do |prop_type|
        if extended_properties[prop_type]
          query_parts << extended_properties[prop_type].map do |key, value|
            (prop_type == "shared" ? "sharedExtendedProperty=" : "privateExtendedProperty=") + "#{key}%3D#{value}"
          end.join("&")
        end
      end
      query = "?" + query_parts.join('&') + parse_options(options)
      event_lookup(query)
    end

    #
    # Find all events that match at least one of the specified extended properties within a given time frame.
    # The lower bound is inclusive, whereas the upper bound is exclusive.
    # Events that overlap the range are included.
    #
    # the +extended_properties+ parameter is set up the same way that it is configured when creating an event
    # for example, providing the following hash { 'shared' => {'p1' => 'v1', 'p2' => v2} } will return the list of events
    # that contain either v1 for shared extended property p1 or v2 for p2.
    #
    # the +options+ parameter accepts
    # :max_results => the maximum number of results to return defaults to 25 the largest number Google accepts is 2500
    # :order_by => how you would like the results ordered, can be either 'startTime' or 'updated'. Defaults to 'startTime'. Note: it must be 'updated' if expand_recurring_events is set to false.
    # :expand_recurring_events => When set to true each instance of a recurring event is returned. Defaults to true.
    #
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_events_by_extended_properties_in_range(extended_properties, start_min, start_max, options = {})
      query_parts = []
      ['shared', 'private'].each do |prop_type|
        if extended_properties[prop_type]
          query_parts << extended_properties[prop_type].map do |key, value|
            (prop_type == "shared" ? "sharedExtendedProperty=" : "privateExtendedProperty=") + "#{key}%3D#{value}"
          end.join("&")
        end
      end
      formatted_start_min = encode_time(start_min)
      formatted_start_max = encode_time(start_max)
      query = "?" + query_parts.join('&') + (query_parts.length > 0 ? '&':'') + "timeMin=#{formatted_start_min}&timeMax=#{formatted_start_max}#{parse_options(options)}"
      event_lookup(query)
    end

    #
    # Attempts to find the event specified by the id
    #  Returns:
    #   an empty array if nothing found.
    #   an array with one element if only one found.
    #   an array of events if many found.
    #
    def find_event_by_id(id)
      return nil unless id
      event_lookup("/#{id}")
    end

    #
    # Creates a new event and immediately saves it.
    # Returns the event
    #
    # ==== Examples
    #   # Use a block
    #   cal.create_event do |e|
    #     e.title = "A New Event"
    #     e.where = "Room 101"
    #   end
    #
    #   # Don't use a block (need to call save manually)
    #   event  = cal.create_event
    #   event.title = "A New Event"
    #   event.where = "Room 101"
    #   event.save
    #
    def create_event(&blk)
      setup_event(Event.new, &blk)
    end

    #
    # Looks for the specified event id.
    # If it is found it, updates it's vales and returns it.
    # If the event is no longer on the server it creates a new one with the specified values.
    # Works like the create_event method.
    #
    def find_or_create_event_by_id(id, &blk)
      if id.nil?
        setup_event(Event.new, &blk)
      else
        setup_event(find_event_by_id(id)[0] || Event.new, &blk)
      end
    end

    #
    # Saves the specified event.
    # This is a callback used by the Event class.
    #
    def save_event(event)
      method = event.new_event? ? :post : :put
      body = event.use_quickadd? ? nil : event.to_json
      query_string =  if event.use_quickadd?
        "/quickAdd?text=#{event.title}"
      elsif event.new_event?
        ''
      else # update existing event.
        "/#{event.id}"
      end

      send_events_request(query_string, method, body)
    end

    #
    # Deletes the specified event.
    # This is a callback used by the Event class.
    #
    def delete_event(event)
      send_events_request("/#{event.id}", :delete)
    end

    protected

    #
    # Set the ID after google assigns it (only necessary when we are creating a new event)
    #
    def update_after_save(response) #:nodoc:
      return if @id && @id != ''
      @raw = JSON.parse(response.body)
      @id = @raw['id']
      @html_link = @raw['htmlLink']

      self
    end

    #
    # Utility method used to centralize the parsing of common query parameters.
    #
    def parse_options(options) # :nodoc
      options[:max_results] ||=  25
      options[:order_by] ||= 'startTime' # other option is 'updated'
      options[:expand_recurring_events] ||= true
      query_string = "&orderBy=#{options[:order_by]}"
      query_string << "&maxResults=#{options[:max_results]}"
      query_string << "&singleEvents=#{options[:expand_recurring_events]}"
      query_string << "&q=#{options[:query]}" unless options[:query].nil?
      query_string
    end

    #
    # Utility method to centralize time encoding.
    #
    def encode_time(time) #:nodoc:
      time.utc.strftime("%FT%TZ")
    end

    #
    # Utility method used to centralize event lookup.
    #
    def event_lookup(query_string = '') #:nodoc:
      begin
        response = send_events_request(query_string, :get)
        parsed_json = JSON.parse(response.body)
        @summary = parsed_json['summary']
        events = Event.build_from_google_feed(parsed_json, self) || []
        return events if events.empty?
        events.length > 1 ? events : [events[0]]
      rescue Google::HTTPNotFound
        return []
      end
    end

    #
    # Utility method used to centralize event setup
    #
    def setup_event(event) #:nodoc:
      event.calendar = self
      if block_given?
        yield(event)
      end
      event.save
      event
    end

    #
    # Wraps the `send` method. Send a calendar related request to Google.
    #
    def send_calendar_request(path_and_query_string, method, content = '')
      @connection.send("/calendars#{path_and_query_string}", method, content)
    end

    #
    # Wraps the `send` method. Send an event related request to Google.
    #
    def send_events_request(path_and_query_string, method, content = '')
      @connection.send("/calendars/#{CGI::escape @id}/events#{path_and_query_string}", method, content)
    end
  end

end

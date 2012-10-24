require 'spec_helper'

describe UserVoice::Collection do

  context 'having an empty result set' do
    let(:client) do
      client = mock(
        :get => {"response_data"=>{"page"=>1, "per_page"=>10, "total_records"=>0, "filter"=>"all", "sort"=>"votes"}, "suggestions"=>[]}
      )
    end
    before do
      @collection = UserVoice::Collection.new(client, '/api/v1/suggestions')
    end

    it "should return size of zero" do
      @collection.size.should == 0
    end

    it 'should have zero entries with #each' do
      @collection.each do |suggestion|
        raise RuntimeError.new('should be empty')
      end
    end

    it 'should convert to empty array with to_a' do
      @collection.to_a.should == []
    end

    it 'should not have first record' do
      @collection[0].should == nil
    end
  end

  context 'having a list with one element' do
    before do
      @client = mock(
        :get => {"response_data"=>{"page"=>1, "per_page"=>10, "total_records"=>1, "filter"=>"all", "sort"=>"votes"}, "suggestions"=>[ {
            "url"=>"http://uservoice-subdomain.uservoice.com/forums/1-general/suggestions/1-idea",
            "id"=>1,
            "state"=>"published",
            "title"=>"a",
            "text"=>"b",
            "formatted_text"=>"b",
            "forum"=>{"id"=>"1", "name"=>"General"}
          }
      ]})
      @collection = UserVoice::Collection.new(@client, '/api/v1/suggestions')
    end

    it 'should have correct size' do
      @collection.size.should == 1
    end

    it 'should yield correct records ids' do
      ids = []
      @collection.each do |val|
        ids.push(val['id'])
      end
      ids.should == [1]
    end

    it 'should map ids' do
      @collection.map do |val|
        val['id']
      end.should == [1]
    end

    it 'should collect ids' do
      @client.should_receive(:get).with("/api/v1/suggestions?per_page=#{UserVoice::Collection::PER_PAGE}&page=1").once

      @collection.collect do |val|
        val['id']
      end.should == [1]

      @collection.map do |val|
        val['id']
      end.should == [1]
    end
  end

  context 'having a list with 301 elements' do
    ELEMENTS = 301 # 4 pages, one record in the last page

    before do
      @client = mock()

      4.times.map do |page_index|
        page_first_index = UserVoice::Collection::PER_PAGE * page_index + 1
        page_last_index = [UserVoice::Collection::PER_PAGE * (page_index + 1), ELEMENTS].min

        @client.stub(:get).with("/api/v1/suggestions?per_page=#{UserVoice::Collection::PER_PAGE}&page=#{page_index+1}") do
          {
            "response_data" => {
              "page"=> page_index+1,
              "per_page" => UserVoice::Collection::PER_PAGE,
              "total_records" => ELEMENTS,
              "filter"=>"all",
              "sort"=>"votes"
            },
            "suggestions"=> page_first_index.upto(page_last_index).map do |idea_index|
              {
                "url"=>"http://uservoice-subdomain.uservoice.com/forums/1-general/suggestions/#{idea_index}-idea",
                "id"=> idea_index,
                "state"=>"published",
                "title"=>"Idea ##{idea_index}",
                "text"=>"Idea ##{idea_index}",
                "formatted_text"=>"Idea ##{idea_index}",
                "forum"=>{"id"=>"1", "name"=>"General"}
              }
            end
          }
        end
      end
      @collection = UserVoice::Collection.new(@client, '/api/v1/suggestions')
    end

    it 'should have correct size' do
      @client.should_receive(:get).with("/api/v1/suggestions?per_page=#{UserVoice::Collection::PER_PAGE}&page=1").once
      @collection.size.should == ELEMENTS
    end

    it 'should the size defined by limit' do
      collection = UserVoice::Collection.new(@client, '/api/v1/suggestions', :limit => 137)
      collection.size.should == 137
      collection.last['id'].should == 137
    end

    it 'should get last element and array size with two api calls' do
      @collection.last['id'].should == ELEMENTS
      @collection.first['id'].should == 1
    end

    it 'should yield correct records ids' do
      ids = []
      @collection.each do |val|
        ids.push(val['id'])
      end
      ids.size.should == ELEMENTS
      ids.should == 1.upto(ELEMENTS).to_a
    end

    it 'should map ids' do
      @collection.map do |val|
        val['id']
      end.should == 1.upto(ELEMENTS).to_a
    end

    it 'should convert to array' do
      @collection.to_a.map do |val|
        val['id']
      end.should == 1.upto(ELEMENTS).to_a
    end
  end
end

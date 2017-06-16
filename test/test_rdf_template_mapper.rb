require 'test_helper'

class TestRdfTemplateMapper < Test::Unit::TestCase
  include Jekyll::RdfClassExtraction
  graph = RDF::Graph.load(TestHelper::TEST_OPTIONS['jekyll_rdf']['path'])
  sparql = SPARQL::Client.new(graph)
  res_helper = ResourceHelper.new(sparql)
  context "the class extraction" do
    should "extract classes from the given source" do
      answer = search_for_classes(sparql)
      assert answer.any? { |class_res| class_res.to_s.eql? "http://xmlns.com/foaf/0.1/Person"}
      assert answer.any? { |class_res| class_res.to_s.eql? "http://pcai042.informatik.uni-leipzig.de/~dtp16/#SpecialPerson"}
      assert answer.any? { |class_res| class_res.to_s.eql? "http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson"}
      assert !(answer.any? { |class_res| class_res.to_s.eql? "http://www.ifi.uio.no/INF3580/simpsons#Homer"})
      assert !(answer.any? { |class_res| class_res.to_s.eql? "http://www.ifi.uio.no/INF3580/simpsons#Lisa"})
      assert !(answer.any? { |class_res| class_res.to_s.eql? "http://placeholder.host.plh/placeholder#Placeholder"})
    end
  end

  context "the resource class creator " do
    setup do
      @classResources = {}
      create_resource_class(search_for_classes(sparql), sparql)
    end

    should "only create instances of RdfResourceClass" do
      assert @classResources.all? {|class_hash, class_res| class_res.is_a?(Jekyll::Drops::RdfResourceClass)}
    end

    should "create certain classes from the source" do
      assert @classResources.any? { |class_hash, class_res| class_res.to_s.eql? "http://xmlns.com/foaf/0.1/Person"}
      assert @classResources.any? { |class_hash, class_res| class_res.to_s.eql? "http://pcai042.informatik.uni-leipzig.de/~dtp16/#SpecialPerson"}
      assert @classResources.any? { |class_hash, class_res| class_res.to_s.eql? "http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson"}
      assert !(@classResources.any? { |class_hash, class_res| class_res.to_s.eql? "http://www.ifi.uio.no/INF3580/simpsons#Homer"})
      assert !(@classResources.any? { |class_hash, class_res| class_res.to_s.eql? "http://www.ifi.uio.no/INF3580/simpsons#Lisa"})
      assert !(@classResources.any? { |class_hash, class_res| class_res.to_s.eql? "http://placeholder.host.plh/placeholder#Placeholder"})
    end

    should "hash each class resource to its uri" do
      assert @classResources.any? {|class_hash, class_res| class_hash.eql? class_res.to_s}
    end

    should "keep subclass relations between class resources" do
      assert (@classResources["http://xmlns.com/foaf/0.1/Person"].subClasses.any?{|class_res| class_res.to_s.eql? "http://pcai042.informatik.uni-leipzig.de/~dtp16/#SpecialPerson"}&&
          @classResources["http://xmlns.com/foaf/0.1/Person"].subClasses.any?{|class_res| class_res.to_s.eql? "http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson"})
      assert @classResources["http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson"].subClasses.any?{|class_res| class_res.to_s.eql? "http://pcai042.informatik.uni-leipzig.de/~dtp16/#SpecialPerson"}
    end

    should "not create any empty subclass relations" do
      assert !@classResources.any?{|class_hash, class_res|
        class_res.subClasses.any?{|class_res2| class_res2.nil?}
      }
    end
  end

  context "the class-template-mapping system" do
    setup do
      classes_to_templates = {
        "http://xmlns.com/foaf/0.1/Person" => "Person",
        "http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson" => "AnotherSpecialPerson"
      }
      @classResources = {}
      create_resource_class(search_for_classes(sparql), sparql)
      assign_class_templates(classes_to_templates)
    end

    should "map the right template to the right class in consideration to its super classes" do
      assert_equal "Person", @classResources["http://xmlns.com/foaf/0.1/Person"].template
      assert_equal "Person", @classResources["http://pcai042.informatik.uni-leipzig.de/~dtp16/#SpecialPerson"].template #"AnotherSpecialPerson"
      assert_equal "AnotherSpecialPerson", @classResources["http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson"].template
      assert_equal "Person", @classResources["http://pcai042.informatik.uni-leipzig.de/~dtp16/#MagridsSpecialClass"].template #"AnotherSpecialPerson"
      #subclasshier... used in map -> problem: subclasses do not get the same template | class to class is not influenced by classHier... only instance to class
    end
  end

  context "the template mapper" do
    setup do
      resources_to_templates = {
        "http://www.ifi.uio.no/INF3580/simpsons#Lisa" => "Lisa",
        "http://placeholder.host.plh/placeholder#Placeholder" => "Placeholder"
        }
      classes_to_templates = {
        "http://xmlns.com/foaf/0.1/Person" => "Person",
        "http://pcai042.informatik.uni-leipzig.de/~dtp16/#SpecialPerson" => "SpecialPerson",
        "http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson" => "AnotherSpecialPerson"
      }
      default_template = "default"
      @mapper = Jekyll::RdfTemplateMapper.new(resources_to_templates, classes_to_templates, default_template, sparql)
    end

    should "map to each instance resource the fitting template" do
      resource = res_helper.basic_resource("http://www.ifi.uio.no/INF3580/simpsons#Homer")
      answer = @mapper.map(resource)
      assert_equal("SpecialPerson", answer)
      resource = res_helper.basic_resource("http://www.ifi.uio.no/INF3580/simpsons#Lisa")
      answer = @mapper.map(resource)
      assert_equal("Lisa", answer)
      resource = res_helper.basic_resource("http://placeholder.host.plh/placeholder#Placeholder")
      answer = @mapper.map(resource)
      assert_equal("Placeholder", answer)
      resource = res_helper.basic_resource("http://www.ifi.uio.no/INF3580/simpsons#Marge")
      answer = @mapper.map(resource)
      assert_equal("Person", answer)
      resource = res_helper.basic_resource("http://pcai042.informatik.uni-leipzig.de/~dtp16/#TestPersonMagrid")
      answer = @mapper.map(resource)
      assert_equal("SpecialPerson", answer)
    end

    should "initailize correctly" do
      assert_equal "Person", @mapper.classResources["http://xmlns.com/foaf/0.1/Person"].template
      assert_equal "SpecialPerson", @mapper.classResources["http://pcai042.informatik.uni-leipzig.de/~dtp16/#SpecialPerson"].template #"AnotherSpecialPerson"
      assert_equal "AnotherSpecialPerson", @mapper.classResources["http://pcai042.informatik.uni-leipzig.de/~dtp16/#AnotherSpecialPerson"].template
      assert_equal "SpecialPerson", @mapper.classResources["http://pcai042.informatik.uni-leipzig.de/~dtp16/#MagridsSpecialClass"].template #"AnotherSpecialPerson"
      #subclasshier... used in map -> problem: subclasses do not get the same template | class to class is not influenced by classHier... only instance to class
    end
  end
end

require File.expand_path '../xref_test_case', __FILE__

class TestRDocClassModule < XrefTestCase

  def setup
    super

    @RM = RDoc::Markup
  end

  def test_comment_equals
    cm = RDoc::ClassModule.new 'Klass'
    cm.comment = '# comment 1'

    assert_equal 'comment 1', cm.comment

    cm.comment = '# comment 2'

    assert_equal "comment 1\n---\ncomment 2", cm.comment

    cm.comment = "# * comment 3"

    assert_equal "comment 1\n---\ncomment 2\n---\n* comment 3", cm.comment
  end

  # handle making a short module alias of yourself

  def test_find_class_named
    @c2.classes_hash['C2'] = @c2

    assert_nil @c2.find_class_named('C1')
  end

  def test_merge
    cm1 = RDoc::ClassModule.new 'Klass'
    cm1.comment = 'klass 1'
    cm1.add_attribute RDoc::Attr.new(nil, 'a1', 'RW', '')
    cm1.add_attribute RDoc::Attr.new(nil, 'a3', 'R', '')
    cm1.add_constant RDoc::Constant.new('C1', nil, '')
    cm1.add_include RDoc::Include.new('I1', '')
    cm1.add_method RDoc::AnyMethod.new(nil, 'm1')

    cm2 = RDoc::ClassModule.new 'Klass'
    cm2.instance_variable_set(:@comment,
                              @RM::Document.new(
                                @RM::Paragraph.new('klass 2')))
    cm2.add_attribute RDoc::Attr.new(nil, 'a2', 'RW', '')
    cm2.add_attribute RDoc::Attr.new(nil, 'a3', 'W', '')
    cm2.add_constant RDoc::Constant.new('C2', nil, '')
    cm2.add_include RDoc::Include.new('I2', '')
    cm2.add_method RDoc::AnyMethod.new(nil, 'm2')

    cm1.merge cm2

    document = @RM::Document.new(
      @RM::Paragraph.new('klass 2'),
      @RM::Paragraph.new('klass 1'))

    assert_equal document, cm1.comment

    expected = [
      RDoc::Attr.new(nil, 'a1', 'RW', ''),
      RDoc::Attr.new(nil, 'a2', 'RW', ''),
      RDoc::Attr.new(nil, 'a3', 'RW', ''),
    ]

    expected.each do |a| a.parent = cm1 end
    assert_equal expected, cm1.attributes.sort

    expected = [
      RDoc::Constant.new('C1', nil, ''),
      RDoc::Constant.new('C2', nil, ''),
    ]

    expected.each do |c| c.parent = cm1 end
    assert_equal expected, cm1.constants.sort

    expected = [
      RDoc::Include.new('I1', ''),
      RDoc::Include.new('I2', ''),
    ]

    expected.each do |i| i.parent = cm1 end
    assert_equal expected, cm1.includes.sort

    expected = [
      RDoc::AnyMethod.new(nil, 'm1'),
      RDoc::AnyMethod.new(nil, 'm2'),
    ]

    expected.each do |m| m.parent = cm1 end
    assert_equal expected, cm1.method_list.sort
  end

  def test_remove_nodoc_children
    parent = RDoc::ClassModule.new 'A'
    parent.modules_hash.replace 'B' => true, 'C' => true
    RDoc::TopLevel.all_modules_hash.replace 'A::B' => true

    parent.classes_hash.replace 'D' => true, 'E' => true
    RDoc::TopLevel.all_classes_hash.replace 'A::D' => true

    parent.remove_nodoc_children

    assert_equal %w[B], parent.modules_hash.keys
    assert_equal %w[D], parent.classes_hash.keys
  end

  def test_superclass
    assert_equal @c3_h1, @c3_h2.superclass
  end

  def test_update_aliases_module

    # we must create modules for this test,
    # to avoid conflicts with other tests
    n1 = @xref_data.add_module RDoc::NormalModule, 'N1'
    n1_n2 = n1.add_module RDoc::NormalModule, 'N2'

    # add constant N1::A1 -> N1::N2
    n1.add_module_alias n1_n2, 'A1'

    # make sure the constant is there,
    # and points to the aliased module
    n1_a1_c = n1.constants.find { |c| c.name == 'A1' }
    refute_nil n1_a1_c
    assert_equal n1_n2, n1_a1_c.is_alias_for

    n1.update_aliases

    # make sure the alias module was created
    n1_a1_m = @xref_data.find_class_or_module 'N1::A1'
    refute_nil n1_a1_m
    assert_equal n1_n2, n1_a1_m.is_alias_for
    refute_equal n1_n2, n1_a1_m

    assert_equal 1, n1_n2.aliases.length
    assert_equal n1_a1_m, n1_n2.aliases[0]

    assert_equal 'N1::N2', n1_n2.full_name
    assert_equal 'N1::A1', n1_a1_m.full_name

  end

  def test_update_aliases_class

    # we must create classes for this test,
    # to avoid conflicts with other tests
    k1 = @xref_data.add_module RDoc::NormalClass, 'K1'
    k1_k2 = k1.add_module RDoc::NormalClass, 'K2'

    # add constant K1::A1 -> K1::K2
    k1.add_module_alias k1_k2, 'A1'

    # make sure the constant is there,
    # and points to the aliased class
    k1_a1_c = k1.constants.find { |c| c.name == 'A1' }
    refute_nil k1_a1_c
    assert_equal k1_k2, k1_a1_c.is_alias_for

    k1.update_aliases

    # make sure the alias class was created
    k1_a1_k = @xref_data.find_class_or_module 'K1::A1'
    refute_nil k1_a1_k
    assert_equal k1_k2, k1_a1_k.is_alias_for
    refute_equal k1_k2, k1_a1_k

    assert_equal 1, k1_k2.aliases.length
    assert_equal k1_a1_k, k1_k2.aliases[0]

    assert_equal 'K1::K2', k1_k2.full_name
    assert_equal 'K1::A1', k1_a1_k.full_name

  end

  def test_update_aliases_reparent

    # we must create modules for this test,
    # to avoid conflicts with other tests
    l1 = @xref_data.add_module RDoc::NormalModule, 'L1'
    l1_l2 = l1.add_module RDoc::NormalModule, 'L2'
    o1 = @xref_data.add_module RDoc::NormalModule, 'O1'

    # add constant O1::A1 -> L1::L2
    o1.add_module_alias l1_l2, 'A1'

    # make sure the constant is there,
    # and points to the aliased module
    o1_a1_c = o1.constants.find { |c| c.name == 'A1' }
    refute_nil o1_a1_c
    assert_equal l1_l2, o1_a1_c.is_alias_for
    refute_equal l1_l2, o1_a1_c

    o1.update_aliases

    # make sure the alias module was created
    o1_a1_m = @xref_data.find_class_or_module 'O1::A1'
    refute_nil o1_a1_m
    assert_equal l1_l2, o1_a1_m.is_alias_for

    assert_equal 1, l1_l2.aliases.length
    assert_equal o1_a1_m, l1_l2.aliases[0]

    assert_equal 'L1::L2', l1_l2.full_name
    assert_equal 'O1::A1', o1_a1_m.full_name

  end

end


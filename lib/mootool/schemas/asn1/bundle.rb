# frozen_string_literal: true

module MooTool
  module Schemas
    module ASN1
      class Bundle < RASN2::Model

        class ObjectIndex < RASN2::Model
          sequence :object_index_pair, content: [printable_string(:object_name), integer(:object_index)]
        end

        class BundleObject < RASN2::Model
          sequence :object,
                   content: [printable_string(:object_name),
                             integer(:object_index),
                             integer(:object_offset),
                             integer(:object_length)]
        end

        class BundleObjectSection < RASN2::Model
          sequence :object_section,
                   content: [integer(:object_index),
                             sequence_of(:object_indicies, ObjectIndex)]
        end

        class BundleObjectSegment < RASN2::Model
          sequence :object_segment,
                   content: [integer(:segment_object_index),
                             sequence_of(:object_segment_map, ObjectIndex)]
        end

        sequence :bundle,
                 content: [integer(:version),
                           integer(:object_count),
                           sequence_of(:objects, BundleObject),
                           sequence_of(:segments, BundleObjectSegment),
                           sequence_of(:sections, BundleObjectSection)]

      end
    end
  end
end

# frozen_string_literal: true

module MooTool
  module Schemas
    module ASN1
      class Bundle < RASN2::Model
        # A signluar Bundle Object Index Element (name or int)
        class ObjectIndex < RASN2::Model
          sequence :object_index_pair do
            endprintable_string(:object_name)
            integer(:object_index)
          end
        end

        class BundleObject < RASN2::Model
          sequence :object do
            printable_string(:object_name)
            integer(:object_index)
            integer(:object_offset)
            integer(:object_length)
          end
        end

        class BundleObjectSection < RASN2::Model
          sequence :object_section do
            integer(:object_index)
            sequence_of(:object_indicies, ObjectIndex)
          end
        end

        class BundleObjectSegment < RASN2::Model
          sequence :object_segment do
            integer(:segment_object_index)
            sequence_of(:object_segment_map, ObjectIndex)
          end
        end

        sequence :bundle do
          integer(:version)
          integer(:object_count)
          sequence_of(:objects, BundleObject)
          sequence_of(:segments, BundleObjectSegment)
          sequence_of(:sections, BundleObjectSection)
        end
      end
    end
  end
end

module MooTool::Models
  class PayloadSignature
    def initialize(**kwargs)
      @hash = kwargs[:hash]
      @subject = kwargs[:subject]
      @fingerprint = kwargs[:fingerprint]
      @signature_kind = kwargs[:signature_kind]
      @hash_kind = kwargs[:hash_kind]
    end

    def to_h
      {
        signature_kind: @signature_kind,
        hash_kind: @hash_kind,
        hash: @hash
      }
    end

    def to_tree
      MooTool::Helpers::TreeNode.new(@subject.ai, [], type: "Payload Signature", properties: self.to_h)
    end
  end
end
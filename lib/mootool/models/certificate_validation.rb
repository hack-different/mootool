module MooTool::Models
  class CertificateValidation
    def initialize(**kwargs)
      @subject = kwargs[:subject]
      @issuer = kwargs[:issuer]
      @fingerprint = kwargs[:fingerprint]
      @digest = kwargs[:digest]
      @key_id = kwargs[:key_id]
      @self_digest = kwargs[:self_digest]
      @valid = kwargs[:valid]
      @attestations = kwargs[:attestations] || []
      @attestations = @attestations.map { |a| CertificateAttestation.new(**a) }
    end

    attr_reader :digest, :subject, :issuer, :fingerprint, :key_id, :valid, :attestations

    def valid?
      @valid
    end

    def to_tree
      attestations = @attestations.map(&:to_tree)
      MooTool::Helpers::TreeNode.new(@subject.ai, attestations, type: "Payload Certificate", id: @fingerprint, properties: {
        issuer: @issuer,
        key_id: @key_id,
        self_signed: @self_digest,
        digest: @digest,
        fingerprint: @fingerprint,
        valid: @valid
      }.compact)
    end
  end
end
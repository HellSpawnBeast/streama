package streama

class Profile {

  String profileName
  String profileLanguage
  Boolean isChild
  Boolean isDeleted = false
  String avatarColor
  File avatar_image

  def getAvatarImageSrc() {
    return avatar_image?.src
  }

  static belongsTo = [user: User]

  static constraints = {
  }
}
